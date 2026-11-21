import Foundation

/// 決まった種から同じ列を出す乱数（SplitMix64）。塔は日付や番号から毎回同じに作る
struct SeededRNG: RandomNumberGenerator, Sendable {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int { Int.random(in: range, using: &self) }
    mutating func chance(_ p: Double) -> Bool { Double.random(in: 0..<1, using: &self) < p }
}

/// 塔の作り方（大きさ・高さ・色・屋根の多さ）
struct TowerRecipe: Sendable {
    var size: Int  // 5 か 7
    var maxHeight: Int
    var pillars: ClosedRange<Int>
    var bridges: ClosedRange<Int>
    var materials: [Material]
    var roofChance: Double
}

enum TowerGenerator {
    /// 種から塔を作る。猫 5 匹がどれも見つけられる塔になるまで、種をずらして作り直す
    static func make(seed: UInt64, recipe: TowerRecipe, catIDs: [Int]) -> Tower {
        for attempt in 0..<400 {
            var rng = SeededRNG(seed: seed &+ UInt64(attempt) &* 0x2545_F491_4F6C_DD1D)
            if let t = attempt1(rng: &rng, recipe: recipe, catIDs: catIDs) { return t }
        }
        // ここには来ない想定（テストで確かめる）。来たら小さな見本の塔
        return Samples.fallback(catIDs: catIDs)
    }

    static func attempt1(rng: inout SeededRNG, recipe: TowerRecipe, catIDs: [Int]) -> Tower? {
        let n = recipe.size
        let c = (n - 1) / 2
        var solids = Set<Cell>()
        var materials: [Cell: Material] = [:]

        func column(_ x: Int, _ y: Int, _ h: Int, _ m: Material) {
            for z in 0..<h {
                let cell = Cell(x: x, y: y, z: z)
                solids.insert(cell)
                if materials[cell] == nil { materials[cell] = m }
            }
        }
        // 真ん中の塔
        let main = recipe.materials[0]
        column(c, c, recipe.maxHeight - rng.int(0...1), main)
        // 柱と台
        for _ in 0..<rng.int(recipe.pillars) {
            let x = rng.int(0...(n - 1)), y = rng.int(0...(n - 1))
            let h = rng.int(1...max(1, recipe.maxHeight - 1))
            let m = recipe.materials[rng.int(0...(recipe.materials.count - 1))]
            column(x, y, h, m)
            if rng.chance(0.45) {
                // となりにもう 1 本（台になる）
                let d = Dir(rawValue: rng.int(0...3))!
                let nx = x + d.dx, ny = y + d.dy
                if (0..<n).contains(nx), (0..<n).contains(ny) { column(nx, ny, max(1, h - rng.int(0...1)), m) }
            }
        }
        // 宙に浮いた橋（ありえない形の塔らしさ）
        for _ in 0..<rng.int(recipe.bridges) {
            let z = rng.int(1...max(1, recipe.maxHeight - 2))
            var x = rng.int(0...(n - 1)), y = rng.int(0...(n - 1))
            let d = Dir(rawValue: rng.int(0...3))!
            let m: Material = recipe.materials.count > 2 ? recipe.materials[2] : .plum
            for _ in 0..<rng.int(2...3) {
                guard (0..<n).contains(x), (0..<n).contains(y) else { break }
                let cell = Cell(x: x, y: y, z: z)
                if !solids.contains(cell) { solids.insert(cell); materials[cell] = m }
                x += d.dx; y += d.dy
            }
        }
        var tower = Tower(size: n, solids: solids, roofs: [], ladders: [], materials: materials, windows: [], cats: [], start: Top(x: c, y: c, h: 1))

        // はしご：一段低い床へ
        var ladders: [Ladder] = []
        for t in tower.tops {
            for d in Dir.allCases {
                let low = Top(x: t.x + d.dx, y: t.y + d.dy, h: t.h - 1)
                guard low.h >= 1, tower.isTop(low) else { continue }
                if rng.chance(0.4) { ladders.append(Ladder(cell: t.cell, dir: d)) }
            }
        }
        tower.ladders = ladders

        // 屋根：高いところに少し
        let highest = tower.tops.map(\.h).max() ?? 1
        var roofs = Set<Cell>()
        for t in tower.tops where t.h >= highest - 1 && rng.chance(recipe.roofChance) {
            if !ladders.contains(where: { $0.upper == t || $0.lower == t }) { roofs.insert(t.cell) }
        }
        tower.roofs = roofs
        tower.ladders = ladders.filter { !roofs.contains($0.upper.cell) && !roofs.contains($0.lower.cell) }

        // 始まりの床：低くて手前（向き 0 で見えるもの）
        // 旅人の体（床の上 0.3〜0.7）まで見える床だけ（手前の柱に隠れない）
        let visible0 = tower.visibleTops(view: 0).filter { t in
            let r = tower.rotated(x: t.x, y: t.y, view: 0)
            // 手前（向き 0 では +x と +y）の同じ高さに壁があると、体の半分が隠れる
            let front = [Cell(x: t.x + 1, y: t.y, z: t.h), Cell(x: t.x, y: t.y + 1, z: t.h)]
            return !front.contains(where: tower.solids.contains)
                && [0.3, 0.7].allSatisfy { tower.isVisible(u: Double(r.u), w: Double(r.w), h: Double(t.h) + $0, view: 0) }
        }
        guard let start = visible0.sorted(by: { a, b in
            let ra = tower.rotated(x: a.x, y: a.y, view: 0), rb = tower.rotated(x: b.x, y: b.y, view: 0)
            return (a.h, -(ra.u + ra.w), a.x, a.y) < (b.h, -(rb.u + rb.w), b.x, b.y)
        }).first else { return nil }
        tower.start = start

        let walker = Walker(tower: tower)
        guard walker.reachable(from: start, view: 0).count >= 3 else { return nil }
        let any = walker.reachableAnyView(from: start)
        let truly = walker.trulyReachable(from: start)

        // 道の先の猫：錯視を使わないと行けない床
        var roofCands = any.subtracting(truly).filter { t in (0..<4).contains { walker.visible($0).contains(t) } }
            .sorted { ($0.h, $0.x, $0.y) < ($1.h, $1.x, $1.y) }
        guard roofCands.count >= 2 else { return nil }
        roofCands.shuffle(using: &rng)
        // 最初の向きのままでは届かない床を先に（回さないと見つからない）
        let reach0 = walker.reachable(from: start, view: 0)
        roofCands.sort { (reach0.contains($0) ? 1 : 0) < (reach0.contains($1) ? 1 : 0) }
        let roofA = roofCands[0]
        guard let roofB = roofCands.dropFirst().first(where: { abs($0.x - roofA.x) + abs($0.y - roofA.y) + abs($0.h - roofA.h) >= 2 }) else { return nil }

        // 窓の猫・影の猫：見える向きが 1〜2 の窓、2 つ以上の窓
        let ladderFaces = Set(tower.ladders.map { Face(cell: $0.cell, dir: $0.dir) })
        var faces: [(Face, [Int])] = []
        for cell in solids.sorted(by: { ($0.z, $0.x, $0.y) < ($1.z, $1.x, $1.y) }) {
            for d in Dir.allCases {
                let f = Face(cell: cell, dir: d)
                guard tower.faceIsOpen(f), !ladderFaces.contains(f) else { continue }
                let views = tower.faceViews(f)
                if !views.isEmpty { faces.append((f, views)) }
            }
        }
        faces.shuffle(using: &rng)
        let few = faces.filter { $0.1.count <= 2 }
        guard let winA = few.first(where: { !$0.1.contains(0) }) else { return nil }
        guard let winB = few.first(where: { $0.0.cell != winA.0.cell && Set($0.1) != Set(winA.1) }) else { return nil }
        guard let shadow = faces.first(where: { $0.1.count >= 2 && $0.0.cell != winA.0.cell && $0.0.cell != winB.0.cell }) else { return nil }
        let marks = Array(shadow.1.shuffled(using: &rng).prefix(2)).sorted()

        let ids = catIDs.count >= 5 ? catIDs : catIDs + Array(repeating: 0, count: 5 - catIDs.count)
        tower.cats = [
            CatSpot(id: 0, kind: .window, catID: ids[0], face: winA.0),
            CatSpot(id: 1, kind: .roof, catID: ids[1], top: roofA),
            CatSpot(id: 2, kind: .window, catID: ids[2], face: winB.0),
            CatSpot(id: 3, kind: .roof, catID: ids[3], top: roofB),
            CatSpot(id: 4, kind: .shadow, catID: ids[4], face: shadow.0, marks: marks),
        ]
        // 飾りの窓（猫のいない窓も多いので、窓を見るだけでは分からない）
        var windows = Set(tower.cats.compactMap(\.face))
        for (f, _) in faces where rng.chance(0.28) { windows.insert(f) }
        tower.windows = windows
        return tower
    }
}

/// どの猫がどの向きで見つけられるか（ヒントと、テストで使う）
extension Tower {
    /// 窓・影の猫が見える向き
    func views(of cat: CatSpot) -> [Int] {
        switch cat.kind {
        case .window: return cat.face.map(faceViews) ?? []
        case .shadow: return cat.marks
        case .roof:
            guard let t = cat.top else { return [] }
            return (0..<4).filter { isVisible(t, view: $0) }
        }
    }

    /// 始まりの床から、どの猫も見つけられるか
    var allCatsFindable: Bool {
        let walker = Walker(tower: self)
        let any = walker.reachableAnyView(from: start)
        return cats.allSatisfy { cat in
            switch cat.kind {
            case .window: return !views(of: cat).isEmpty
            case .shadow: return cat.marks.count == 2 && cat.marks.allSatisfy { v in cat.face.map { isVisible($0, view: v) } ?? false }
            case .roof: return cat.top.map { any.contains($0) } ?? false
            }
        }
    }
}
