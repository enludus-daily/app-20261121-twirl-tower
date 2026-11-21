import Foundation
import Observation
import SwiftUI

enum ActiveSheet: String, Identifiable {
    case shelf, book, settings, paywall, result
    var id: String { rawValue }
}

/// 上に出る短い知らせ
struct Banner: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var lamp = false
}

/// アプリ全体の状態。画面はこれを見る。遊びの手続きは Hunt（Model/Game.swift）
@MainActor
@Observable
final class AppModel {
    // 保存するもの
    var save = SaveData()
    var onboarded = false
    var soundOn = true
    var hapticsOn = true
    var paywallOffered = false

    // 遊んでいる塔
    var currentID: TowerID
    var hunt: Hunt
    var now: Date
    let calendar: Calendar

    // 動き（回す・歩く・光る）
    var dragAngle: Double?
    var snapFrom = 0.0
    var snapTo = 0.0
    var snapStart: Date?
    var walkFrom: Top?
    var walkTo: Top?
    var walkStart: Date?
    var walking = false
    var glowStart: Date?
    var glowTops: [Top] = []
    var popStart: [Int: Date] = [:]
    var shakeStart: Date?
    var busyUntil = Date.distantPast
    var frameTick = 0

    // 画面
    var activeSheet: ActiveSheet?
    var banner: Banner?
    var lastCompleted: TowerID?
    var reduceMotion = false
    /// 撮影のとき：動きを止めた絵にする
    var still = false
    var proOverride = false
    /// 案内を何ページ目から見せるか（撮影用）
    var onboardingPage = 0

    // 手応え（sensoryFeedback の引き金）
    var pressTick = 0
    var turnTick = 0
    var snapTick = 0
    var connectTick = 0
    var findTick = 0
    var markTick = 0
    var missTick = 0
    var completeTick = 0

    let purchases: PurchaseStore
    private let persists: Bool
    @ObservationIgnored private var towerCache: [TowerID: Tower] = [:]
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    static let proID = ProductID.pro(bundleID: Bundle.main.bundleIdentifier ?? "com.enludus.daily.002")

    init(persists: Bool = true, now: Date = Date(), calendar: Calendar = .current) {
        self.persists = persists
        self.now = now
        self.calendar = calendar
        purchases = PurchaseStore(productIDs: [AppModel.proID], proProductIDs: [AppModel.proID])
        let today = Days.key(now, calendar: calendar)
        currentID = .daily(today)
        hunt = Hunt(tower: Catalog.tower(.daily(today)))
        if persists { load() }
        open(.daily(today), announce: false)
    }

    var today: String { Days.key(now, calendar: calendar) }
    var yesterday: String { Days.offset(now, days: -1, calendar: calendar) }
    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var streak: Int { save.currentStreak(today: today, yesterday: yesterday) }

    func tower(_ id: TowerID) -> Tower {
        if let t = towerCache[id] { return t }
        let t = Catalog.tower(id)
        towerCache[id] = t
        return t
    }

    func canPlay(_ id: TowerID) -> Bool { isPro || Catalog.isFree(id, today: today) }

    // MARK: 保存（できごとのたびに 1 回。毎秒は保存しない）

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "save"), let s = try? JSONDecoder().decode(SaveData.self, from: data) { save = s }
        onboarded = d.bool(forKey: "onboarded")
        soundOn = d.object(forKey: "sound") as? Bool ?? true
        hapticsOn = d.object(forKey: "haptics") as? Bool ?? true
        paywallOffered = d.bool(forKey: "paywallOffered")
    }

    func persist() {
        save.progress[currentID.key] = hunt.progress
        guard persists else { return }
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(save) { d.set(data, forKey: "save") }
        d.set(onboarded, forKey: "onboarded")
        d.set(soundOn, forKey: "sound")
        d.set(hapticsOn, forKey: "haptics")
        d.set(paywallOffered, forKey: "paywallOffered")
    }

    func setSound(_ on: Bool) { soundOn = on; persist() }
    func setHaptics(_ on: Bool) { hapticsOn = on; persist() }

    func finishOnboarding() {
        withAnimation(.easeOut(duration: 0.35)) { onboarded = true }
        persist()
        play(.page)
        showBanner(Catalog.name(currentID), tr("ドラッグで回して、猫を 5 匹さがそう", "Drag to turn the tower and find 5 cats"))
    }

    // MARK: 塔を開く

    func open(_ id: TowerID, announce: Bool = true) {
        if currentID != id { save.progress[currentID.key] = hunt.progress }
        currentID = id
        hunt = Hunt(tower: tower(id), progress: save.progress(id))
        dragAngle = nil
        snapStart = nil
        snapTo = Double(hunt.view)
        walkFrom = nil; walkTo = nil; walking = false
        glowTops = []
        popStart = [:]
        if announce {
            persist()
            play(.page)
            showBanner(Catalog.name(id), hunt.isComplete ? tr("ぜんぶ見つけた塔。もう一度ながめられる", "All found here. Enjoy the view again") : trf("猫 %d / 5", "Cats %d / 5", hunt.progress.found.count))
        }
    }

    // MARK: 回す

    /// 今描く角度（向きの単位）
    func displayAngle(at date: Date) -> Double {
        if let d = dragAngle { return d }
        guard let s = snapStart else { return Double(hunt.view) + 4 * floor(snapTo / 4) }
        let t = min(1, date.timeIntervalSince(s) / 0.34)
        // 少し行きすぎて戻る（吸い付くように止まる）
        let c1 = 1.4, c3 = c1 + 1
        let e = 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
        return snapFrom + (snapTo - snapFrom) * (reduceMotion ? 1 : e)
    }

    var isRotating: Bool { dragAngle != nil || (snapStart.map { Date().timeIntervalSince($0) < 0.34 } ?? false) }

    func dragChanged(_ dx: CGFloat) {
        guard !walking else { return }
        let base = snapStart == nil ? snapTo : displayAngle(at: Date())
        if dragAngle == nil { snapStart = nil; snapTo = base }
        let newAngle = snapTo - Double(dx) / 170
        if let old = dragAngle, floor(old + 0.5) != floor(newAngle + 0.5) {
            turnTick += 1
            play(.tick)
        }
        dragAngle = newAngle
    }

    func dragEnded(predicted dx: CGFloat) {
        guard let current = dragAngle else { return }
        let predicted = snapTo - Double(dx) / 170
        // はじいた勢いで最大 1 つ先まで
        var target = (current + (predicted - current) * 0.35).rounded()
        target = min(max(target, current.rounded() - 1), current.rounded() + 1)
        dragAngle = nil
        snap(from: current, to: target)
    }

    /// ボタンで回す（+1 = 左へ、−1 = 右へ）
    func turn(_ steps: Int) {
        guard !walking else { return }
        press()
        let from = snapStart == nil ? snapTo : displayAngle(at: Date())
        snap(from: from, to: snapTo.rounded() + Double(steps))
    }

    private func snap(from: Double, to: Double) {
        let before = hunt.reachableNow
        let oldView = hunt.view
        snapFrom = from
        snapTo = to
        snapStart = Date()
        let newView = ((Int(to) % 4) + 4) % 4
        hunt.turn(newView - oldView)
        markBusy(0.4)
        snapTick += 1
        play(.snap)
        // 新しい道がつながったら、その床を順に光らせる
        let after = hunt.reachableNow
        let added = after.subtracting(before)
        if newView != oldView, !added.isEmpty {
            let w = Projection(tower: hunt.tower, angle: Double(newView), scale: 1, origin: .zero)
            glowTops = added.sorted {
                let a = w.point(Double($0.x), Double($0.y), Double($0.h)), b = w.point(Double($1.x), Double($1.y), Double($1.h))
                return hypot(a.x, a.y) < hypot(b.x, b.y)
            }
            glowStart = Date().addingTimeInterval(0.25)
            markBusy(0.25 + Double(added.count) * 0.055 + 1.0)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                self.connectTick += 1
                self.play(.connect)
            }
        }
        persist()
    }

    // MARK: たたく

    func tap(_ hit: ArtHit?) {
        guard !walking, !isRotating else { return }
        switch hit {
        case .cat(let i): tapCat(i)
        case .top(let t): walk(to: t)
        case .wall, .none: break
        }
    }

    func tapCat(_ index: Int) {
        let result = hunt.tapCat(index)
        switch result {
        case .found(let id): found(id)
        case .mark(let id, let complete):
            if complete {
                found(id)
            } else {
                markTick += 1
                play(.mark)
                showBanner(tr("足あと 1 / 2", "Paw prints 1 / 2"), tr("べつの向きからも、足あとを探そう", "Look for more prints from another side"))
                persist()
            }
        case .farAway(let id):
            guard let t = hunt.tower.cats[id].top else { return }
            if hunt.pathTo(t) != nil {
                walk(to: t)
            } else {
                miss(tr("まだ道がつながっていない", "The path isn't connected yet"), tr("塔を回すと、見え方と道が変わる", "Turn the tower to change how paths line up"))
            }
        case .already:
            let c = hunt.tower.cats[index]
            let info = Catalog.cats[c.catID]
            press()
            showBanner(info.name.text, trf("好物：%@", "Loves: %@", info.food.text))
        case .nothing:
            break
        }
    }

    func walk(to t: Top) {
        guard let path = hunt.pathTo(t) else {
            if t != hunt.at {
                miss(tr("まだ道がつながっていない", "The path isn't connected yet"), tr("画面で隣り合って見える床は、つながる", "Floors that look connected on screen are connected"))
            }
            return
        }
        walking = true
        Task { @MainActor in
            for (a, b) in zip(path, path.dropFirst()) {
                self.walkFrom = a
                self.walkTo = b
                self.walkStart = Date()
                self.markBusy(0.25)
                self.play(.step)
                try? await Task.sleep(for: .milliseconds(self.reduceMotion ? 60 : 210))
                let got = self.hunt.step(to: b)
                self.walkFrom = nil
                self.walkTo = nil
                for id in got { self.found(id) }
                if self.hunt.isComplete { break }
            }
            self.walking = false
            self.persist()
        }
    }

    private func miss(_ title: String, _ detail: String) {
        missTick += 1
        shakeStart = Date()
        markBusy(0.5)
        play(.far)
        showBanner(title, detail)
    }

    private func found(_ id: Int) {
        let info = Catalog.cats[hunt.tower.cats[id].catID]
        save.record(cat: info.id)
        popStart[id] = Date()
        markBusy(1.4)
        findTick += 1
        play(.find)
        let first = (save.catsFound[info.id] ?? 0) == 1
        showBanner(trf("%@ をみつけた", "Found %@", info.name.text), first ? trf("図鑑に追加：好物は%@", "New in the book — loves %@", info.food.text) : trf("猫 %d / 5", "Cats %d / 5", hunt.progress.found.count), lamp: true)
        if hunt.isComplete { complete() }
        persist()
    }

    private func complete() {
        save.complete(currentID, today: today, yesterday: yesterday)
        lastCompleted = currentID
        persist()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1300))
            self.completeTick += 1
            self.play(.complete)
            self.activeSheet = .result
        }
    }

    /// 結果を閉じたあと：最初に 1 つ解いたときだけ Pro を 1 回だけ案内する。ほかは棚へ（次の塔をえらぶ）
    func resultClosed() {
        let offer = !isPro && !paywallOffered
        if offer {
            paywallOffered = true
            persist()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            self.activeSheet = offer ? .paywall : .shelf
        }
    }

    // MARK: ヒント

    func askHint() {
        press()
        guard let h = hunt.nextHint() else {
            showBanner(tr("ヒントはない", "No hints"), tr("この塔の猫はぜんぶ見つけた", "You found every cat here"))
            return
        }
        play(.hint)
        let c = hunt.tower.cats[h.catIndex]
        let kind: String = switch c.kind {
        case .window: tr("窓の中", "in a window")
        case .roof: tr("道の先の屋上", "on a rooftop down the path")
        case .shadow: tr("影の足あと", "shadow paw prints")
        }
        let way: String = switch h.turns {
        case 1: tr("左へ 1 回まわす", "turn left once")
        case -1: tr("右へ 1 回まわす", "turn right once")
        case 2: tr("裏側から見る", "look from the back")
        default: tr("この向きのまま", "this side works")
        }
        switch h.level {
        case 1: showBanner(trf("ヒント 1：%@", "Hint 1: %@", way), trf("次の猫は%@", "The next cat is %@", kind))
        case 2: showBanner(trf("ヒント 2：%@", "Hint 2: %@", way), c.kind == .roof ? tr("黄色い床をたどると近づける", "Follow the glowing floor") : tr("あたりを丸で示した", "The area is circled"))
        default: showBanner(tr("ヒント 3：光っている", "Hint 3: it's glowing"), tr("光る所をたたこう", "Tap the glow"))
        }
        persist()
    }

    // MARK: 絵の状態

    func artState(at date: Date) -> ArtState {
        let angle = displayAngle(at: date)
        var s = ArtState(angle: angle)
        s.snapped = isRotating ? nil : hunt.view
        s.found = hunt.progress.found
        s.marks = hunt.progress.marks
        s.walker = walkFrom ?? hunt.at
        s.walkerTo = walkTo
        if let ws = walkStart, walkTo != nil { s.walkT = min(1, date.timeIntervalSince(ws) / 0.21) }
        if s.snapped != nil, !walking { s.reachable = hunt.reachableNow }
        if let h = hunt.hint, h.view == hunt.view, s.snapped != nil {
            s.hint = h
            if h.level >= 2 { s.hintPath = Set(hunt.hintPath2()) }
        }
        if let g = glowStart {
            for (i, t) in glowTops.enumerated() {
                let local = date.timeIntervalSince(g) - Double(i) * 0.055
                if local > 0, local < 1.0 { s.glow[t] = reduceMotion ? 0.6 : sin(local * .pi) }
            }
        }
        for (id, start) in popStart {
            let t = date.timeIntervalSince(start)
            if t < 0.6 { s.pop[id] = reduceMotion ? 1 : springPop(t / 0.6) }
        }
        let wagAge = popStart.values.map { date.timeIntervalSince($0) }.min() ?? 99
        s.wag = (still || reduceMotion || wagAge > 1.4) ? 0.4 : 0.4 + sin(wagAge * 14) * 0.9 * (1 - wagAge / 1.4)
        s.time = date.timeIntervalSinceReferenceDate
        s.still = still || reduceMotion
        return s
    }

    /// 0.6 → 1 に弾む
    private func springPop(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return 0.6 + 0.4 * (1 - exp(-6 * x) * cos(10 * x))
    }

    /// 揺れ（失敗）：減衰する横ずれ
    func shakeOffset(at date: Date) -> CGFloat {
        guard !reduceMotion, let s = shakeStart else { return 0 }
        let t = date.timeIntervalSince(s)
        guard t < 0.42 else { return 0 }
        return CGFloat(sin(t * 48) * 8 * (1 - t / 0.42))
    }

    /// 絵を動かし続けるか（止まっている間は描き直さない）
    func animating(at date: Date) -> Bool {
        if still { return false }
        if dragAngle != nil || walking { return true }
        if hunt.hint?.level ?? 0 >= 3, !reduceMotion { return true }
        return date < busyUntil
    }

    private func markBusy(_ seconds: Double) {
        let until = Date().addingTimeInterval(seconds)
        if until > busyUntil { busyUntil = until }
        frameTick += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000) + 30))
            self.frameTick += 1
        }
    }

    // MARK: 音・知らせ

    func press() {
        pressTick += 1
        play(.tap)
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func showBanner(_ title: String, _ detail: String, lamp: Bool = false) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { banner = Banner(title: title, detail: detail, lamp: lamp) }
        bannerTask?.cancel()
        guard !still else { return }
        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.banner = nil }
        }
    }

    // MARK: 一覧のための数

    func catsFound(in id: TowerID) -> Int {
        id == currentID ? hunt.progress.found.count : save.progress(id).found.count
    }

    func isDone(_ id: TowerID) -> Bool {
        id == currentID ? hunt.progress.done : save.progress(id).done
    }

    func lamps(_ id: TowerID) -> Int {
        id == currentID ? hunt.progress.lamps : save.progress(id).lamps
    }

    var pastDays: [String] { (1...14).map { Days.offset(now, days: -$0, calendar: calendar) } }
}

extension Hunt {
    /// ヒント 2 以上：屋上の猫への道（今の向きで行ける所まで）を光らせる
    func hintPath2() -> [Top] {
        guard let h = hint, h.level >= 2, let t = tower.cats[h.catIndex].top else { return [] }
        if let p = walker.path(from: at, to: t, view: view) { return Array(p.dropFirst()) }
        // まだつながっていない：今の向きで行ける床のうち、猫に近い所まで
        let r = reachableNow
        guard let near = r.min(by: { abs($0.x - t.x) + abs($0.y - t.y) + abs($0.h - t.h) < abs($1.x - t.x) + abs($1.y - t.y) + abs($1.h - t.h) }) else { return [] }
        return Array((walker.path(from: at, to: near, view: view) ?? []).dropFirst())
    }
}
