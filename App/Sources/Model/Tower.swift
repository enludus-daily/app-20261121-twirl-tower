import Foundation

// 塔のかたちと「見え方」のきまり（画面から切り離してテストする）。
//
// 座標：x・y は床の升（0..<size）、z は高さ（0 が一番下）。升の中心で回すので size は奇数。
// 向き（view）は 0〜3。向き v では、床の座標を中心のまわりに 90°×v 回してから等角に描く。
// カメラは回した座標で (+1, +1, +1) の方から見下ろしている。
// だから (1, 1, 1) だけずれた点は画面で重なり、「画面で隣り合って見えた床は、つながる」が成り立つ（錯視の道）。

struct Cell: Hashable, Codable, Sendable {
    var x: Int
    var y: Int
    var z: Int
}

/// 床の向き（世界の座標の 4 方向）
enum Dir: Int, CaseIterable, Codable, Sendable {
    case east, north, west, south  // +x, +y, -x, -y

    var dx: Int { [1, 0, -1, 0][rawValue] }
    var dy: Int { [0, 1, 0, -1][rawValue] }
}

/// 歩ける床（ブロックの上の面）。h はブロックの上の面の高さ（= z + 1）
struct Top: Hashable, Codable, Sendable {
    var x: Int
    var y: Int
    var h: Int
    var cell: Cell { Cell(x: x, y: y, z: h - 1) }
}

/// ブロックの横の面（窓）
struct Face: Hashable, Codable, Sendable {
    var cell: Cell
    var dir: Dir
}

enum Material: Int, Codable, Sendable, CaseIterable {
    case terracotta, mint, sand, plum
}

/// はしご：ブロック cell の dir 側の面にかかり、上の床（cell の上）と、dir 側の一段低い床をつなぐ
struct Ladder: Hashable, Codable, Sendable {
    var cell: Cell
    var dir: Dir
    var upper: Top { Top(x: cell.x, y: cell.y, h: cell.z + 1) }
    var lower: Top { Top(x: cell.x + dir.dx, y: cell.y + dir.dy, h: cell.z) }
}

/// 猫の隠れ方
enum CatKind: String, Codable, Sendable {
    /// 窓の中。その窓が見える向きでしか見えない
    case window
    /// 屋上で寝ている。歩いてそこまで行くと見つかる（道がつながったときだけ届く）
    case roof
    /// 影の猫。2 つの向きで足あとを見つけると現れる
    case shadow
}

struct CatSpot: Hashable, Codable, Sendable, Identifiable {
    var id: Int  // 塔の中の番号（0〜4）
    var kind: CatKind
    var catID: Int  // 図鑑の猫
    var face: Face?  // window・shadow
    var top: Top?  // roof
    /// shadow：足あとが見える 2 つの向き
    var marks: [Int] = []
}

/// 回した座標
struct Rotated: Hashable, Sendable {
    var u: Int
    var w: Int
}

struct Tower: Sendable {
    var size: Int
    var solids: Set<Cell>
    var roofs: Set<Cell>  // 上に屋根が乗ったブロック（上の面は歩けない）
    var ladders: [Ladder]
    var materials: [Cell: Material]
    var windows: Set<Face>  // 飾りの窓（猫のいる窓も含む）
    var cats: [CatSpot]
    var start: Top

    var center: Int { (size - 1) / 2 }
    var height: Int { (solids.map(\.z).max() ?? 0) + 1 }

    // MARK: 回す

    static func rotate(_ a: Int, _ b: Int, view: Int) -> (Int, Int) {
        var (p, q) = (a, b)
        for _ in 0..<((view % 4 + 4) % 4) { (p, q) = (-q, p) }
        return (p, q)
    }

    func rotated(x: Int, y: Int, view: Int) -> Rotated {
        let (u, w) = Tower.rotate(x - center, y - center, view: view)
        return Rotated(u: u, w: w)
    }

    /// 回した座標での向き（法線）
    static func rotated(_ dir: Dir, view: Int) -> (Int, Int) { rotate(dir.dx, dir.dy, view: view) }

    /// 向き v で、その面がこちらを向いているか（法線が +u か +w）
    static func facesCamera(_ dir: Dir, view: Int) -> Bool {
        let (nu, nw) = rotated(dir, view: view)
        return nu + nw > 0
    }

    // MARK: 床

    var tops: [Top] {
        solids.filter { !solids.contains(Cell(x: $0.x, y: $0.y, z: $0.z + 1)) && !roofs.contains($0) }
            .map { Top(x: $0.x, y: $0.y, h: $0.z + 1) }
            .sorted { ($0.h, $0.x, $0.y) < ($1.h, $1.x, $1.y) }
    }

    func isTop(_ t: Top) -> Bool {
        let c = t.cell
        return solids.contains(c) && !roofs.contains(c) && !solids.contains(Cell(x: c.x, y: c.y, z: c.z + 1))
    }

    /// 画面の上の位置（向き v）。P は横、Q は縦（どちらも整数）。(1,1,1) ずれた点は同じ値になる
    func screenKey(_ t: Top, view: Int) -> (p: Int, q: Int) {
        let r = rotated(x: t.x, y: t.y, view: view)
        return (r.u - r.w, r.u + r.w - 2 * t.h)
    }

    /// 本当に隣り合う床（向きによらない）：同じ高さで隣の升、またははしご
    func trueNeighbors(_ t: Top) -> [Top] {
        var out: [Top] = []
        for d in Dir.allCases {
            let n = Top(x: t.x + d.dx, y: t.y + d.dy, h: t.h)
            if isTop(n) { out.append(n) }
        }
        for l in ladders {
            if l.upper == t, isTop(l.lower) { out.append(l.lower) }
            if l.lower == t, isTop(l.upper) { out.append(l.upper) }
        }
        return out
    }

    /// 向き v で、画面で隣り合って見える床（錯視の道を含む）。見えている床どうしだけ
    func screenNeighbors(_ t: Top, view: Int, visible: Set<Top>) -> [Top] {
        guard visible.contains(t) else { return [] }
        let (p, q) = screenKey(t, view: view)
        return visible.filter { o in
            let k = screenKey(o, view: view)
            return abs(k.p - p) == 1 && abs(k.q - q) == 1
        }.sorted { ($0.h, $0.x, $0.y) < ($1.h, $1.x, $1.y) }
    }

    func neighbors(_ t: Top, view: Int, visible: Set<Top>) -> [Top] {
        var seen = Set<Top>()
        var out: [Top] = []
        for n in trueNeighbors(t) + screenNeighbors(t, view: view, visible: visible) where seen.insert(n).inserted {
            out.append(n)
        }
        return out
    }

    /// 錯視の道か（本当には隣り合っていない）
    func isIllusion(_ a: Top, _ b: Top) -> Bool { !trueNeighbors(a).contains(b) }

    // MARK: 見えるか

    /// 屋根（四角すい、高さ 0.5）の中か
    private func insideRoof(_ cell: Cell, du: Double, dw: Double, dh: Double) -> Bool {
        guard roofs.contains(cell) else { return false }
        let m = max(abs(du), abs(dw))
        return dh >= 0 && dh < 0.5 * (1 - 2 * m)
    }

    /// 回した座標の点 (u, w, h) から、カメラの方へまっすぐ進んで、ブロックや屋根に当たるか
    func isVisible(u: Double, w: Double, h: Double, view: Int) -> Bool {
        // 回した座標 → 世界の升
        let inv = (4 - view % 4) % 4
        let limit = Double(size + height + 2)
        var t = 0.04
        while t < limit {
            let pu = u + t, pw = w + t, ph = h + t
            let cu = Int((pu).rounded()), cw = Int((pw).rounded())
            let (dx, dy) = Tower.rotate(cu, cw, view: inv)
            let x = dx + center, y = dy + center
            let zf = ph.rounded(.down)
            let z = Int(zf)
            if solids.contains(Cell(x: x, y: y, z: z)) { return false }
            // 下の升の屋根（屋根はブロックの上に乗る）
            if insideRoof(Cell(x: x, y: y, z: z - 1), du: pu - Double(cu), dw: pw - Double(cw), dh: ph - zf) { return false }
            t += 0.05
        }
        return true
    }

    func isVisible(_ top: Top, view: Int) -> Bool {
        let r = rotated(x: top.x, y: top.y, view: view)
        return isVisible(u: Double(r.u), w: Double(r.w), h: Double(top.h) + 0.02, view: view)
    }

    /// 面が見えるか：こちらを向いていて、その先が空いていて、前に何もない
    func isVisible(_ face: Face, view: Int) -> Bool {
        guard Tower.facesCamera(face.dir, view: view) else { return false }
        let r = rotated(x: face.cell.x, y: face.cell.y, view: view)
        let (nu, nw) = Tower.rotated(face.dir, view: view)
        return isVisible(u: Double(r.u) + 0.52 * Double(nu), w: Double(r.w) + 0.52 * Double(nw), h: Double(face.cell.z) + 0.45, view: view)
    }

    func visibleTops(view: Int) -> Set<Top> {
        Set(tops.filter { isVisible($0, view: view) })
    }

    func faceViews(_ face: Face) -> [Int] { (0..<4).filter { isVisible(face, view: $0) } }

    func faceIsOpen(_ face: Face) -> Bool {
        !solids.contains(Cell(x: face.cell.x + face.dir.dx, y: face.cell.y + face.dir.dy, z: face.cell.z))
    }
}

/// 歩いて行ける所を調べる（向きを変えるのは自由）
struct Walker {
    let tower: Tower
    private var visibleCache: [Set<Top>]

    init(tower: Tower) {
        self.tower = tower
        visibleCache = (0..<4).map { tower.visibleTops(view: $0) }
    }

    func visible(_ view: Int) -> Set<Top> { visibleCache[(view % 4 + 4) % 4] }

    /// 向き v のまま、from から to までの道（from と to を含む）。届かなければ nil
    func path(from: Top, to: Top, view: Int) -> [Top]? {
        if from == to { return [from] }
        var prev: [Top: Top] = [from: from]
        var queue = [from]
        var i = 0
        while i < queue.count {
            let t = queue[i]; i += 1
            for n in tower.neighbors(t, view: view, visible: visible(view)) where prev[n] == nil {
                prev[n] = t
                if n == to {
                    var out = [to]
                    var c = to
                    while c != from { c = prev[c]!; out.append(c) }
                    return out.reversed()
                }
                queue.append(n)
            }
        }
        return nil
    }

    func reachable(from: Top, view: Int) -> Set<Top> {
        var seen: Set<Top> = [from]
        var queue = [from]
        var i = 0
        while i < queue.count {
            let t = queue[i]; i += 1
            for n in tower.neighbors(t, view: view, visible: visible(view)) where seen.insert(n).inserted { queue.append(n) }
        }
        return seen
    }

    /// 本当の道だけで行ける所（錯視を使わない）
    func trulyReachable(from: Top) -> Set<Top> {
        var seen: Set<Top> = [from]
        var queue = [from]
        var i = 0
        while i < queue.count {
            let t = queue[i]; i += 1
            for n in tower.trueNeighbors(t) where seen.insert(n).inserted { queue.append(n) }
        }
        return seen
    }

    struct State: Hashable { var top: Top; var view: Int }

    /// 向きを変えながら行ける所。答えは、そこへ行くまでの (床, 向き) の列
    func route(from: Top, view: Int, to goal: Top) -> [State]? {
        let s0 = State(top: from, view: (view % 4 + 4) % 4)
        var prev: [State: State] = [s0: s0]
        var queue = [s0]
        var i = 0
        while i < queue.count {
            let s = queue[i]; i += 1
            if s.top == goal {
                var out = [s]
                var c = s
                while c != s0 { c = prev[c]!; out.append(c) }
                return out.reversed()
            }
            var next: [State] = [State(top: s.top, view: (s.view + 1) % 4), State(top: s.top, view: (s.view + 3) % 4)]
            for n in tower.neighbors(s.top, view: s.view, visible: visible(s.view)) { next.append(State(top: n, view: s.view)) }
            for n in next where prev[n] == nil {
                prev[n] = s
                queue.append(n)
            }
        }
        return nil
    }

    func reachableAnyView(from: Top) -> Set<Top> {
        var seen: Set<State> = []
        var queue: [State] = []
        for v in 0..<4 { let s = State(top: from, view: v); seen.insert(s); queue.append(s) }
        var i = 0
        while i < queue.count {
            let s = queue[i]; i += 1
            for n in tower.neighbors(s.top, view: s.view, visible: visible(s.view)) {
                for v in 0..<4 {
                    let ns = State(top: n, view: v)
                    if seen.insert(ns).inserted { queue.append(ns) }
                }
            }
        }
        return Set(seen.map(\.top))
    }
}
