import Foundation

/// 1 つの塔の進み具合（保存する）
struct TowerProgress: Codable, Equatable, Sendable {
    var found: Set<Int> = []
    /// 影の猫の足あと（"猫の番号-向き"）
    var marks: Set<String> = []
    var hints = 0
    var done = false
    var lamps = 0
    var view = 0
    var at: Top?
    var foundOrder: [Int] = []
}

/// ヒント（3 段階：向き → 場所のあたり → 光る）
struct Hint: Equatable, Sendable {
    var catIndex: Int
    var level: Int  // 1〜3
    var view: Int  // その猫が見える（行ける）向き
    /// 今の向きから何回まわすか（+1 = 左へ、-1 = 右へ、2 = 裏へ、0 = このまま）
    var turns: Int
}

/// 遊びの手続き（画面から切り離す）
struct Hunt: Sendable {
    let tower: Tower
    let walker: Walker
    var progress: TowerProgress
    var hint: Hint?

    init(tower: Tower, progress: TowerProgress = TowerProgress()) {
        self.tower = tower
        walker = Walker(tower: tower)
        var p = progress
        if p.at == nil || !(p.at.map(tower.isTop) ?? false) { p.at = tower.start }
        p.view = (p.view % 4 + 4) % 4
        self.progress = p
    }

    var view: Int { progress.view }
    var at: Top { progress.at ?? tower.start }
    var isComplete: Bool { progress.found.count >= tower.cats.count }

    mutating func turn(_ steps: Int) {
        progress.view = ((progress.view + steps) % 4 + 4) % 4
        if let h = hint { hint = Hint(catIndex: h.catIndex, level: h.level, view: h.view, turns: Hunt.turns(from: progress.view, to: h.view)) }
    }

    // MARK: 歩く

    /// 床をたたいた：今の向きで行けるなら、その道（今いる床を含む）
    func pathTo(_ t: Top) -> [Top]? {
        guard t != at else { return nil }
        return walker.path(from: at, to: t, view: view)
    }

    /// 1 歩進んだ。そこで寝ている猫を見つける
    mutating func step(to t: Top) -> [Int] {
        progress.at = t
        var got: [Int] = []
        for c in tower.cats where c.kind == .roof && c.top == t && !progress.found.contains(c.id) {
            find(c.id)
            got.append(c.id)
        }
        return got
    }

    /// 今の向きで見えている床（歩いて行ける・行けないにかかわらず）
    var visibleTops: Set<Top> { walker.visible(view) }

    /// 今の向きで、今いる床から行ける床
    var reachableNow: Set<Top> { walker.reachable(from: at, view: view) }

    // MARK: 見つける

    enum TapResult: Equatable { case found(Int), mark(Int, complete: Bool), farAway(Int), already, nothing }

    /// 猫（窓・屋上）や足あとをたたいた
    mutating func tapCat(_ index: Int) -> TapResult {
        guard tower.cats.indices.contains(index) else { return .nothing }
        let c = tower.cats[index]
        if progress.found.contains(c.id) { return .already }
        switch c.kind {
        case .window:
            guard let f = c.face, tower.isVisible(f, view: view) else { return .nothing }
            find(c.id)
            return .found(c.id)
        case .roof:
            return .farAway(c.id)
        case .shadow:
            guard c.marks.contains(view) else { return .nothing }
            progress.marks.insert(Hunt.markKey(c.id, view))
            let all = c.marks.allSatisfy { progress.marks.contains(Hunt.markKey(c.id, $0)) }
            if all { find(c.id) }
            return .mark(c.id, complete: all)
        }
    }

    static func markKey(_ cat: Int, _ view: Int) -> String { "\(cat)-\(view)" }

    func hasMark(_ cat: Int, view: Int) -> Bool { progress.marks.contains(Hunt.markKey(cat, view)) }

    private mutating func find(_ id: Int) {
        guard progress.found.insert(id).inserted else { return }
        progress.foundOrder.append(id)
        if hint?.catIndex == id { hint = nil }
        if isComplete {
            progress.done = true
            progress.lamps = Hunt.lamps(hints: progress.hints)
        }
    }

    static func lamps(hints: Int) -> Int { hints == 0 ? 3 : (hints <= 3 ? 2 : 1) }

    // MARK: ヒント

    static func turns(from: Int, to: Int) -> Int {
        let d = ((to - from) % 4 + 4) % 4
        return d == 3 ? -1 : d
    }

    /// ヒントの相手：見つけやすい順（窓 → 影 → 屋上）
    var hintTarget: Int? {
        let order: [CatKind] = [.window, .shadow, .roof]
        for k in order {
            if let c = tower.cats.first(where: { $0.kind == k && !progress.found.contains($0.id) && reachableCat($0) }) { return c.id }
        }
        return nil
    }

    private func reachableCat(_ c: CatSpot) -> Bool {
        c.kind != .roof || c.top.map { walker.route(from: at, view: view, to: $0) != nil } ?? false
    }

    /// その猫を見つけるために、次に向くとよい向き
    func hintView(for c: CatSpot) -> Int {
        switch c.kind {
        case .window:
            let vs = tower.views(of: c)
            if vs.contains(view) { return view }
            return vs.min { abs(Hunt.turns(from: view, to: $0)) < abs(Hunt.turns(from: view, to: $1)) } ?? view
        case .shadow:
            return c.marks.first { !hasMark(c.id, view: $0) } ?? view
        case .roof:
            guard let t = c.top, let route = walker.route(from: at, view: view, to: t) else { return view }
            // 歩いて行ける所まで行ったあとで、最初に向きを変える向き
            return route.first { $0.view != view }?.view ?? view
        }
    }

    /// ヒントを 1 段進める（同じ猫なら 3 段まで）
    mutating func nextHint() -> Hint? {
        guard let target = hintTarget else { hint = nil; return nil }
        let c = tower.cats[target]
        let v = hintView(for: c)
        let level = hint?.catIndex == target ? min(3, (hint?.level ?? 0) + 1) : 1
        if hint?.catIndex != target || (hint?.level ?? 0) < 3 { progress.hints += 1 }
        hint = Hint(catIndex: target, level: level, view: v, turns: Hunt.turns(from: view, to: v))
        return hint
    }

    /// 屋上の猫への道で、今の向きで光らせる床（ヒント 3）
    func hintPath() -> [Top] {
        guard let h = hint, h.level >= 3, let t = tower.cats[h.catIndex].top else { return [] }
        return walker.path(from: at, to: t, view: view) ?? []
    }
}

/// 日付の名前（端末の暦で）
enum Days {
    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func offset(_ date: Date, days: Int, calendar: Calendar) -> String {
        key(calendar.date(byAdding: .day, value: days, to: date) ?? date, calendar: calendar)
    }
}

/// 端末に残すもの（UserDefaults に JSON で。毎秒は保存しない：できごとのたびに 1 回）
struct SaveData: Codable, Equatable, Sendable {
    var progress: [String: TowerProgress] = [:]
    /// 図鑑：猫ごとに見つけた回数
    var catsFound: [Int: Int] = [:]
    var dailyDone: Set<String> = []
    var streak = 0
    var bestStreak = 0
    var lastDaily: String?

    var towersDone: Int { progress.values.filter(\.done).count }
    var catsKnown: Int { catsFound.count }

    func progress(_ id: TowerID) -> TowerProgress { progress[id.key] ?? TowerProgress() }

    /// 塔を解いた。毎日の塔なら続けた日数を数える
    mutating func complete(_ id: TowerID, today: String, yesterday: String) {
        if case .daily(let d) = id, d == today, !dailyDone.contains(d) {
            dailyDone.insert(d)
            streak = lastDaily == yesterday ? streak + 1 : (lastDaily == today ? streak : 1)
            lastDaily = today
            bestStreak = max(bestStreak, streak)
        }
    }

    mutating func record(cat: Int) { catsFound[cat, default: 0] += 1 }

    /// 続けた日数（今日か昨日に解いていなければ 0 と見せる。責めない言い方は画面で）
    func currentStreak(today: String, yesterday: String) -> Int {
        lastDaily == today || lastDaily == yesterday ? streak : 0
    }
}
