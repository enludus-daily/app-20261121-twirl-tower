import SwiftUI

/// 等角の絵の描き方（回す角度は「向き」の単位。1.0 = 90°）。
/// 回した座標 (u, w, h) → 画面：x = (u − w)·0.866·s、y = (u + w)·0.5·s − h·s。
/// このとき (1, 1, 1) だけずれた点は同じ所に描かれる（錯視の道のきまりと同じ）
struct Projection {
    let tower: Tower
    let angle: Double
    let scale: CGFloat
    let origin: CGPoint

    private var theta: Double { angle * .pi / 2 }

    func rot(_ a: Double, _ b: Double) -> (u: Double, w: Double) {
        let c = cos(theta), s = sin(theta)
        return (a * c - b * s, a * s + b * c)
    }

    /// 世界の座標（升の中心が整数）→ 画面
    func point(_ x: Double, _ y: Double, _ h: Double) -> CGPoint {
        let c = Double(tower.center)
        let r = rot(x - c, y - c)
        return screen(r.u, r.w, h)
    }

    func screen(_ u: Double, _ w: Double, _ h: Double) -> CGPoint {
        CGPoint(x: origin.x + CGFloat((u - w) * 0.866) * scale, y: origin.y + CGFloat((u + w) * 0.5 - h) * scale)
    }

    func depth(_ x: Double, _ y: Double, _ h: Double) -> Double {
        let c = Double(tower.center)
        let r = rot(x - c, y - c)
        return r.u + r.w + h
    }

    /// どの角度でも収まる大きさと位置
    static func fit(_ tower: Tower, in size: CGSize, padding: CGFloat = 20, maxScale: CGFloat = 70) -> (CGFloat, CGPoint) {
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        let c = Double(tower.center)
        for step in 0..<16 {
            let th = Double(step) * .pi / 8
            for cell in tower.solids {
                for (ox, oy) in [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)] {
                    let a = Double(cell.x) - c + ox, b = Double(cell.y) - c + oy
                    let u = a * cos(th) - b * sin(th), w = a * sin(th) + b * cos(th)
                    for h in [Double(cell.z), Double(cell.z) + 1.7] {
                        let x = (u - w) * 0.866, y = (u + w) * 0.5 - h
                        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
            }
        }
        guard minX.isFinite else { return (40, CGPoint(x: size.width / 2, y: size.height / 2)) }
        let bw = max(1, maxX - minX), bh = max(1, maxY - minY)
        let s = min((size.width - padding * 2) / CGFloat(bw), (size.height - padding * 2) / CGFloat(bh), maxScale)
        let origin = CGPoint(x: size.width / 2 - CGFloat((minX + maxX) / 2) * s, y: size.height / 2 - CGFloat((minY + maxY) / 2) * s)
        return (max(8, s), origin)
    }
}

/// 絵に描く状態（AppModel から毎フレーム作る）
struct ArtState {
    var angle: Double
    /// 90° で止まっているときの向き（回している途中は nil）
    var snapped: Int?
    var found: Set<Int> = []
    var marks: Set<String> = []
    var walker: Top?
    var walkerTo: Top?
    var walkT: Double = 0
    var reachable: Set<Top> = []
    var hintPath: Set<Top> = []
    var hint: Hint?
    var glow: [Top: Double] = [:]
    var pop: [Int: Double] = [:]  // 見つけた直後の弾み（0→1）
    var wag: Double = 0
    var time: Double = 0
    var showWalker = true
    var still = false
}

enum ArtHit: Equatable {
    case cat(Int)
    case top(Top)
    case wall
}

/// 塔を描く（Canvas）
struct TowerArt: View {
    let tower: Tower
    let state: ArtState
    var padding: CGFloat = 24
    var maxScale: CGFloat = 70

    var body: some View {
        Canvas { ctx, size in
            let (s, o) = Projection.fit(tower, in: size, padding: padding, maxScale: maxScale)
            let p = Projection(tower: tower, angle: state.angle, scale: s, origin: o)
            TowerPainter(tower: tower, proj: p, state: state).draw(&ctx)
        }
    }
}

struct TowerPainter {
    let tower: Tower
    let proj: Projection
    let state: ArtState

    private enum Item {
        case cube(Cell)
        case roofCat(Int)
        case walker
    }

    private func items() -> [(Double, Item)] {
        var list: [(Double, Item)] = []
        for c in tower.solids {
            list.append((proj.depth(Double(c.x), Double(c.y), Double(c.z)), .cube(c)))
        }
        for cat in tower.cats where cat.kind == .roof {
            guard let t = cat.top else { continue }
            if state.showWalker, state.walker == t, !state.found.contains(cat.id) { continue }
            list.append((proj.depth(Double(t.x), Double(t.y), Double(t.h)) + 0.45, .roofCat(cat.id)))
        }
        if state.showWalker, let w = state.walker {
            var d = proj.depth(Double(w.x), Double(w.y), Double(w.h)) + 0.5
            if let to = state.walkerTo { d = max(d, proj.depth(Double(to.x), Double(to.y), Double(to.h)) + 0.5) }
            list.append((d, .walker))
        }
        return list.sorted { $0.0 < $1.0 }
    }

    func draw(_ ctx: inout GraphicsContext) {
        for (_, item) in items() {
            switch item {
            case .cube(let c): drawCube(&ctx, c)
            case .roofCat(let i): drawRoofCat(&ctx, tower.cats[i])
            case .walker: drawWalker(&ctx)
            }
        }
        // 塔の陰に入っても見失わないよう、旅人の輪郭を薄く上に重ねる
        if state.showWalker, state.walker != nil {
            var ghost = ctx
            ghost.opacity = 0.35
            drawWalker(&ghost)
        }
    }

    // MARK: 面

    private func normal(_ d: Dir) -> (u: Double, w: Double) { proj.rot(Double(d.dx), Double(d.dy)) }

    func faceFacing(_ d: Dir) -> Bool {
        let n = normal(d)
        return n.u + n.w > 0.02
    }

    /// 面の上の点：s は横（−0.5〜0.5）、t は高さ（0〜1）
    func facePoint(_ cell: Cell, _ d: Dir, _ s: Double, _ t: Double) -> CGPoint {
        let tx = Double(-d.dy), ty = Double(d.dx)
        return proj.point(Double(cell.x) + 0.5 * Double(d.dx) + s * tx, Double(cell.y) + 0.5 * Double(d.dy) + s * ty, Double(cell.z) + t)
    }

    func facePath(_ cell: Cell, _ d: Dir) -> Path {
        var p = Path()
        p.move(to: facePoint(cell, d, -0.5, 0))
        p.addLine(to: facePoint(cell, d, 0.5, 0))
        p.addLine(to: facePoint(cell, d, 0.5, 1))
        p.addLine(to: facePoint(cell, d, -0.5, 1))
        p.closeSubpath()
        return p
    }

    func topPath(_ x: Int, _ y: Int, _ h: Int, inset: Double = 0) -> Path {
        let e = 0.5 - inset
        var p = Path()
        let fx = Double(x), fy = Double(y), fh = Double(h)
        p.move(to: proj.point(fx - e, fy - e, fh))
        p.addLine(to: proj.point(fx + e, fy - e, fh))
        p.addLine(to: proj.point(fx + e, fy + e, fh))
        p.addLine(to: proj.point(fx - e, fy + e, fh))
        p.closeSubpath()
        return p
    }

    private func wall(_ c: Cell) -> Wall { Wall.of(tower.materials[c] ?? .sand) }

    private func drawCube(_ ctx: inout GraphicsContext, _ c: Cell) {
        let w = wall(c)
        for d in Dir.allCases where faceFacing(d) {
            // 隣にブロックがある面は見えない
            if tower.solids.contains(Cell(x: c.x + d.dx, y: c.y + d.dy, z: c.z)) { continue }
            let n = normal(d)
            let k = max(0, min(1, n.u / max(0.001, n.u + n.w)))
            let shade = w.left.mix(w.right, k)
            let path = facePath(c, d)
            ctx.fill(path, with: .color(shade.color))
            // 目地（石を積んだ線）
            var seam = Path()
            seam.move(to: facePoint(c, d, -0.5, 0.5))
            seam.addLine(to: facePoint(c, d, 0.5, 0.5))
            ctx.stroke(seam, with: .color(w.trim.color.opacity(0.18)), lineWidth: 0.6)
            ctx.stroke(path, with: .color(w.trim.color.opacity(0.35)), lineWidth: 0.7)
            // 浮いた塔の底：一番下は少し濃い帯
            if c.z == 0 || !tower.solids.contains(Cell(x: c.x, y: c.y, z: c.z - 1)) {
                var band = Path()
                band.move(to: facePoint(c, d, -0.5, 0))
                band.addLine(to: facePoint(c, d, 0.5, 0))
                band.addLine(to: facePoint(c, d, 0.5, 0.12))
                band.addLine(to: facePoint(c, d, -0.5, 0.12))
                band.closeSubpath()
                ctx.fill(band, with: .color(w.trim.color.opacity(0.55)))
            }
            let face = Face(cell: c, dir: d)
            if tower.windows.contains(face) { drawWindow(&ctx, face) }
            if tower.ladders.contains(where: { $0.cell == c && $0.dir == d }) { drawLadder(&ctx, c, d) }
            for cat in tower.cats where cat.kind == .shadow && cat.face == face { drawPaws(&ctx, cat) }
        }
        // 上の面
        let above = Cell(x: c.x, y: c.y, z: c.z + 1)
        guard !tower.solids.contains(above) else { return }
        let top = topPath(c.x, c.y, c.z + 1)
        ctx.fill(top, with: .color(w.top.color))
        ctx.stroke(top, with: .color(w.trim.color.opacity(0.3)), lineWidth: 0.7)
        if tower.roofs.contains(c) {
            drawRoof(&ctx, c)
            return
        }
        let t = Top(x: c.x, y: c.y, h: c.z + 1)
        // 敷石（内側の線）
        ctx.stroke(topPath(c.x, c.y, c.z + 1, inset: 0.12), with: .color(w.trim.color.opacity(0.16)), lineWidth: 0.6)
        if let g = state.glow[t], g > 0 {
            ctx.fill(topPath(c.x, c.y, c.z + 1, inset: 0.06), with: .color(Lamp.glow.opacity(0.55 * g)))
        }
        if state.hintPath.contains(t) {
            ctx.fill(topPath(c.x, c.y, c.z + 1, inset: 0.18), with: .color(Lamp.glow.opacity(0.6)))
        }
        if state.snapped != nil, state.reachable.contains(t), state.walker != t {
            // 行ける床に小さな飛び石の印
            let center = proj.point(Double(c.x), Double(c.y), Double(c.z + 1))
            let r = proj.scale * 0.07
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 1.4, y: center.y - r * 0.8, width: r * 2.8, height: r * 1.6)), with: .color(Ink.panel.opacity(0.75)))
        }
    }

    private func drawRoof(_ ctx: inout GraphicsContext, _ c: Cell) {
        let apex = proj.point(Double(c.x), Double(c.y), Double(c.z) + 1.7)
        for d in Dir.allCases where faceFacing(d) {
            var tri = Path()
            tri.move(to: facePoint(Cell(x: c.x, y: c.y, z: c.z + 1), d, -0.55, 0))
            tri.addLine(to: facePoint(Cell(x: c.x, y: c.y, z: c.z + 1), d, 0.55, 0))
            tri.addLine(to: apex)
            tri.closeSubpath()
            let n = normal(d)
            let k = max(0, min(1, n.u / max(0.001, n.u + n.w)))
            ctx.fill(tri, with: .color(Wall.roofLight.mix(Wall.roof, k).color))
            ctx.stroke(tri, with: .color(Wall.roof.color.opacity(0.6)), lineWidth: 0.6)
        }
        // 風見の小旗
        var pole = Path()
        pole.move(to: apex)
        pole.addLine(to: CGPoint(x: apex.x, y: apex.y - proj.scale * 0.32))
        ctx.stroke(pole, with: .color(Wall.wood.color), lineWidth: 1)
        var flag = Path()
        flag.move(to: CGPoint(x: apex.x, y: apex.y - proj.scale * 0.32))
        flag.addLine(to: CGPoint(x: apex.x + proj.scale * 0.18, y: apex.y - proj.scale * 0.26))
        flag.addLine(to: CGPoint(x: apex.x, y: apex.y - proj.scale * 0.2))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(Mint.accent))
    }

    /// アーチの窓
    func windowPath(_ f: Face) -> Path {
        var p = Path()
        let c = f.cell, d = f.dir
        p.move(to: facePoint(c, d, -0.2, 0.16))
        p.addLine(to: facePoint(c, d, 0.2, 0.16))
        p.addLine(to: facePoint(c, d, 0.2, 0.55))
        for i in 1...8 {
            let a = Double(i) / 8 * .pi
            p.addLine(to: facePoint(c, d, 0.2 * cos(a), 0.55 + 0.22 * sin(a)))
        }
        p.closeSubpath()
        return p
    }

    private func drawWindow(_ ctx: inout GraphicsContext, _ f: Face) {
        let cat = tower.cats.first { $0.kind == .window && $0.face == f }
        let found = cat.map { state.found.contains($0.id) } ?? false
        let path = windowPath(f)
        ctx.fill(path, with: .color((found ? Wall.windowLit : Wall.window).color))
        ctx.stroke(path, with: .color(Wall.of(tower.materials[f.cell] ?? .sand).trim.color), lineWidth: 1)
        let center = facePoint(f.cell, f.dir, 0, 0.42)
        let s = proj.scale
        if let cat {
            let info = Catalog.cats[cat.catID]
            let pop = state.pop[cat.id] ?? 1
            if found {
                CatPainter.head(&ctx, at: center, size: s * 0.36 * (0.7 + 0.3 * pop), coat: info.coat, happy: true)
            } else {
                // 見つかっていない猫：影と 2 つの目だけ
                CatPainter.peek(&ctx, at: center, size: s * 0.34)
            }
            hintMark(&ctx, cat: cat.id, at: center)
        } else {
            // 猫のいない窓：植木鉢かカーテン（決まった形）
            let k = (f.cell.x * 7 + f.cell.y * 3 + f.cell.z * 5 + f.dir.rawValue) % 3
            if k == 0 {
                let r = s * 0.07
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 2, y: center.y + r * 0.6, width: r * 4, height: r * 1.6)), with: .color(Mint.accent))
            } else if k == 1 {
                var cur = Path()
                cur.move(to: facePoint(f.cell, f.dir, -0.18, 0.72))
                cur.addLine(to: facePoint(f.cell, f.dir, 0.0, 0.72))
                cur.addLine(to: facePoint(f.cell, f.dir, -0.18, 0.2))
                cur.closeSubpath()
                ctx.fill(cur, with: .color(Lamp.soft.opacity(0.8)))
            }
        }
    }

    private func drawLadder(_ ctx: inout GraphicsContext, _ c: Cell, _ d: Dir) {
        let wood = Wall.wood.color
        for s in [-0.16, 0.16] {
            var rail = Path()
            rail.move(to: facePoint(c, d, s, 1.04))
            rail.addLine(to: facePoint(c, d, s, -0.02))
            ctx.stroke(rail, with: .color(wood), lineWidth: max(1, proj.scale * 0.04))
        }
        for t in stride(from: 0.15, through: 0.9, by: 0.19) {
            var rung = Path()
            rung.move(to: facePoint(c, d, -0.16, t))
            rung.addLine(to: facePoint(c, d, 0.16, t))
            ctx.stroke(rung, with: .color(wood), lineWidth: max(0.8, proj.scale * 0.03))
        }
    }

    private func drawPaws(_ ctx: inout GraphicsContext, _ cat: CatSpot) {
        guard let f = cat.face else { return }
        let found = state.found.contains(cat.id)
        let center = facePoint(f.cell, f.dir, 0, 0.45)
        let s = proj.scale
        if found {
            CatPainter.sitting(&ctx, at: CGPoint(x: center.x, y: center.y + s * 0.18), size: s * 0.52, coat: Catalog.cats[cat.catID].coat, tail: state.wag, happy: true, shadowy: true)
            return
        }
        guard let v = state.snapped, cat.marks.contains(v) else { return }
        let marked = state.marks.contains(Hunt.markKey(cat.id, v))
        CatPainter.paws(&ctx, at: center, size: s * 0.32, color: marked ? Lamp.glow : Ink.panel.opacity(0.7))
        if !marked { hintMark(&ctx, cat: cat.id, at: center) }
    }

    private func drawRoofCat(_ ctx: inout GraphicsContext, _ cat: CatSpot) {
        guard let t = cat.top else { return }
        let base = proj.point(Double(t.x), Double(t.y), Double(t.h))
        let info = Catalog.cats[cat.catID]
        let s = proj.scale
        if state.found.contains(cat.id) {
            let pop = state.pop[cat.id] ?? 1
            CatPainter.sitting(&ctx, at: base, size: s * 0.6 * (0.6 + 0.4 * pop), coat: info.coat, tail: state.wag, happy: true)
        } else {
            CatPainter.curled(&ctx, at: base, size: s * 0.5, coat: info.coat)
            hintMark(&ctx, cat: cat.id, at: CGPoint(x: base.x, y: base.y - s * 0.1))
        }
    }

    private func drawWalker(_ ctx: inout GraphicsContext) {
        guard let from = state.walker else { return }
        var p = proj.point(Double(from.x), Double(from.y), Double(from.h))
        if let to = state.walkerTo {
            let q = proj.point(Double(to.x), Double(to.y), Double(to.h))
            let t = state.walkT
            p = CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t - sin(t * .pi) * proj.scale * 0.12)
        }
        WalkerPainter.draw(&ctx, at: p, size: proj.scale * 0.62)
    }

    /// ヒント 2：あたりを大きな点線の丸で（少しずらす）。ヒント 3：光る輪
    private func hintMark(_ ctx: inout GraphicsContext, cat: Int, at c: CGPoint) {
        guard let h = state.hint, h.catIndex == cat else { return }
        if h.level >= 3 {
            glowRing(&ctx, at: c, radius: proj.scale * 0.42)
        } else if h.level == 2 {
            let r = proj.scale * 1.1
            let o = CGPoint(x: c.x + proj.scale * 0.35, y: c.y - proj.scale * 0.2)
            ctx.stroke(Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2)), with: .color(Lamp.glow.opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }
    }

    private func glowRing(_ ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat) {
        let pulse = state.still ? 1 : 0.75 + 0.25 * sin(state.time * 5)
        let rr = r * CGFloat(pulse)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(Lamp.glow), lineWidth: 2.5)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(Lamp.glow.opacity(0.18)))
    }

    // MARK: たたいた所

    /// 画面の点 → 何をたたいたか（手前から調べる）
    func hit(_ point: CGPoint) -> ArtHit? {
        let s = proj.scale
        for (_, item) in items().reversed() {
            switch item {
            case .roofCat(let i):
                guard let t = tower.cats[i].top else { continue }
                let b = proj.point(Double(t.x), Double(t.y), Double(t.h))
                let c = CGPoint(x: b.x, y: b.y - s * 0.15)
                if hypot(point.x - c.x, point.y - c.y) < max(22, s * 0.42) { return .cat(i) }
            case .walker:
                continue
            case .cube(let c):
                var onCube = false
                for d in Dir.allCases where faceFacing(d) {
                    if tower.solids.contains(Cell(x: c.x + d.dx, y: c.y + d.dy, z: c.z)) { continue }
                    let face = Face(cell: c, dir: d)
                    if let cat = tower.cats.first(where: { ($0.kind == .window || $0.kind == .shadow) && $0.face == face }) {
                        let center = facePoint(c, d, 0, 0.45)
                        if hypot(point.x - center.x, point.y - center.y) < max(22, s * 0.4) { return .cat(cat.id) }
                    }
                    if facePath(c, d).contains(point) { onCube = true }
                }
                let above = Cell(x: c.x, y: c.y, z: c.z + 1)
                if !tower.solids.contains(above), topPath(c.x, c.y, c.z + 1).contains(point) {
                    if tower.roofs.contains(c) { return .wall }
                    return .top(Top(x: c.x, y: c.y, h: c.z + 1))
                }
                if onCube { return .wall }
            }
        }
        return nil
    }
}

// MARK: - 猫と旅人の絵

enum CatPainter {
    struct Colors {
        var body: Color, patch: Color?, patch2: Color?, belly: Color?, ear: Color, eye: Color
    }

    static func colors(_ coat: Coat) -> Colors {
        switch coat {
        case .ginger: Colors(body: Color(hex: 0xE79A4E), patch: Color(hex: 0xC26F2E), patch2: nil, belly: Color(hex: 0xF8DDB8), ear: Color(hex: 0xC26F2E), eye: Color(hex: 0x3B2C47))
        case .black: Colors(body: Color(hex: 0x2F2833), patch: nil, patch2: nil, belly: nil, ear: Color(hex: 0x1F1A22), eye: Lamp.glow)
        case .white: Colors(body: Color(hex: 0xFBF6EF), patch: nil, patch2: nil, belly: nil, ear: Color(hex: 0xF1C6C0), eye: Color(hex: 0x5E9A84))
        case .gray: Colors(body: Color(hex: 0x8F8A99), patch: Color(hex: 0x6F6A79), patch2: nil, belly: Color(hex: 0xC9C4D1), ear: Color(hex: 0x6F6A79), eye: Lamp.deep)
        case .calico: Colors(body: Color(hex: 0xFBF4EA), patch: Color(hex: 0xE39A55), patch2: Color(hex: 0x3A3036), belly: nil, ear: Color(hex: 0xE39A55), eye: Color(hex: 0x3B2C47))
        case .tuxedo: Colors(body: Color(hex: 0x2F2833), patch: nil, patch2: nil, belly: Color(hex: 0xFBF6EF), ear: Color(hex: 0x1F1A22), eye: Lamp.glow)
        case .cream: Colors(body: Color(hex: 0xF3DDB5), patch: Color(hex: 0xE2C08E), patch2: nil, belly: Color(hex: 0xFBF0DC), ear: Color(hex: 0xE2C08E), eye: Color(hex: 0x3B2C47))
        case .tabby: Colors(body: Color(hex: 0xA77F59), patch: Color(hex: 0x6E4E35), patch2: nil, belly: Color(hex: 0xE3CBAE), ear: Color(hex: 0x6E4E35), eye: Color(hex: 0x5E9A84))
        case .siamese: Colors(body: Color(hex: 0xF4E6D0), patch: Color(hex: 0x5A4036), patch2: nil, belly: nil, ear: Color(hex: 0x5A4036), eye: Color(hex: 0x6FA6D6))
        case .smoke: Colors(body: Color(hex: 0xB9B0C6), patch: Color(hex: 0x958BA6), patch2: nil, belly: Color(hex: 0xE2DCEA), ear: Color(hex: 0x958BA6), eye: Lamp.deep)
        }
    }

    private static func ears(_ ctx: inout GraphicsContext, head c: CGPoint, r: CGFloat, color: Color) {
        for side in [-1.0, 1.0] {
            var e = Path()
            let sx = CGFloat(side)
            e.move(to: CGPoint(x: c.x + sx * r * 0.25, y: c.y - r * 0.8))
            e.addLine(to: CGPoint(x: c.x + sx * r * 0.95, y: c.y - r * 1.35))
            e.addLine(to: CGPoint(x: c.x + sx * r * 0.95, y: c.y - r * 0.35))
            e.closeSubpath()
            ctx.fill(e, with: .color(color))
        }
    }

    private static func eyes(_ ctx: inout GraphicsContext, head c: CGPoint, r: CGFloat, color: Color, happy: Bool) {
        for side in [-1.0, 1.0] {
            let ex = c.x + CGFloat(side) * r * 0.38, ey = c.y - r * 0.05
            if happy {
                var a = Path()
                a.addArc(center: CGPoint(x: ex, y: ey + r * 0.08), radius: r * 0.16, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.stroke(a, with: .color(Color(hex: 0x3B2C47)), lineWidth: max(1, r * 0.11))
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: ex - r * 0.12, y: ey - r * 0.15, width: r * 0.24, height: r * 0.3)), with: .color(color))
            }
        }
    }

    /// 窓から顔だけ
    static func head(_ ctx: inout GraphicsContext, at c: CGPoint, size: CGFloat, coat: Coat, happy: Bool) {
        let col = colors(coat)
        let r = size * 0.5
        ears(&ctx, head: c, r: r, color: col.ear)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.85, width: r * 2, height: r * 1.75)), with: .color(col.body))
        if let p = col.patch {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.9, y: c.y - r * 0.85, width: r * 0.9, height: r * 0.7)), with: .color(p))
        }
        if let p2 = col.patch2 {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.1, y: c.y - r * 0.8, width: r * 0.75, height: r * 0.6)), with: .color(p2))
        }
        eyes(&ctx, head: c, r: r, color: col.eye, happy: happy)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.08, y: c.y + r * 0.25, width: r * 0.16, height: r * 0.11)), with: .color(Color(hex: 0xE58C8C)))
    }

    /// 見つかっていない窓の猫：影と目
    static func peek(_ ctx: inout GraphicsContext, at c: CGPoint, size: CGFloat) {
        let r = size * 0.5
        let shade = Color(hex: 0x1E1626)
        ears(&ctx, head: c, r: r, color: shade)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.85, width: r * 2, height: r * 1.75)), with: .color(shade))
        for side in [-1.0, 1.0] {
            let ex = c.x + CGFloat(side) * r * 0.38, ey = c.y - r * 0.05
            ctx.fill(Path(ellipseIn: CGRect(x: ex - r * 0.13, y: ey - r * 0.13, width: r * 0.26, height: r * 0.26)), with: .color(Lamp.glow))
        }
    }

    /// 座った猫（base は足もと）。tail はしっぽの揺れ（ラジアン）
    static func sitting(_ ctx: inout GraphicsContext, at base: CGPoint, size: CGFloat, coat: Coat, tail: Double, happy: Bool, shadowy: Bool = false) {
        let col = colors(coat)
        let h = size
        // しっぽ
        var tp = Path()
        let root = CGPoint(x: base.x + h * 0.22, y: base.y - h * 0.08)
        let sway = CGFloat(sin(tail)) * h * 0.18
        tp.move(to: root)
        tp.addQuadCurve(to: CGPoint(x: base.x + h * 0.42 + sway * 0.4, y: base.y - h * 0.55 + abs(sway) * 0.2), control: CGPoint(x: base.x + h * 0.55 + sway, y: base.y - h * 0.1))
        ctx.stroke(tp, with: .color(col.patch ?? col.body), style: StrokeStyle(lineWidth: h * 0.09, lineCap: .round))
        // からだ
        let body = CGRect(x: base.x - h * 0.27, y: base.y - h * 0.6, width: h * 0.54, height: h * 0.6)
        ctx.fill(Path(ellipseIn: body), with: .color(col.body))
        if let b = col.belly {
            ctx.fill(Path(ellipseIn: CGRect(x: base.x - h * 0.13, y: base.y - h * 0.45, width: h * 0.26, height: h * 0.4)), with: .color(b))
        }
        if let p2 = col.patch2 {
            ctx.fill(Path(ellipseIn: CGRect(x: base.x - h * 0.25, y: base.y - h * 0.5, width: h * 0.22, height: h * 0.25)), with: .color(p2))
        }
        // 頭
        let hc = CGPoint(x: base.x, y: base.y - h * 0.72)
        head(&ctx, at: hc, size: h * 0.46, coat: coat, happy: happy)
        if shadowy {
            // 影の猫：うっすら紫の縁
            ctx.stroke(Path(ellipseIn: body.insetBy(dx: -1, dy: -1)), with: .color(Color(hex: 0x8E74A2).opacity(0.6)), lineWidth: 1)
        }
    }

    /// 丸くなって寝ている猫（屋上）
    static func curled(_ ctx: inout GraphicsContext, at base: CGPoint, size: CGFloat, coat: Coat) {
        let col = colors(coat)
        let w = size, h = size * 0.5
        let rect = CGRect(x: base.x - w / 2, y: base.y - h * 0.95, width: w, height: h)
        ctx.fill(Path(ellipseIn: rect), with: .color(col.body))
        if let p = col.patch {
            ctx.fill(Path(ellipseIn: CGRect(x: rect.minX + w * 0.1, y: rect.minY + h * 0.08, width: w * 0.4, height: h * 0.45)), with: .color(p))
        }
        if let p2 = col.patch2 {
            ctx.fill(Path(ellipseIn: CGRect(x: rect.midX, y: rect.minY + h * 0.15, width: w * 0.3, height: h * 0.4)), with: .color(p2))
        }
        // 頭と耳
        let hc = CGPoint(x: rect.maxX - w * 0.2, y: rect.minY + h * 0.35)
        let r = h * 0.42
        ears(&ctx, head: hc, r: r, color: col.ear)
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x - r, y: hc.y - r * 0.8, width: r * 2, height: r * 1.6)), with: .color(col.body))
        // 閉じた目
        var e = Path()
        e.move(to: CGPoint(x: hc.x - r * 0.5, y: hc.y))
        e.addLine(to: CGPoint(x: hc.x - r * 0.15, y: hc.y + r * 0.05))
        e.move(to: CGPoint(x: hc.x + r * 0.15, y: hc.y + r * 0.05))
        e.addLine(to: CGPoint(x: hc.x + r * 0.5, y: hc.y))
        ctx.stroke(e, with: .color(Color(hex: 0x3B2C47)), lineWidth: max(0.8, r * 0.12))
        // しっぽを体に巻く
        var tp = Path()
        tp.move(to: CGPoint(x: rect.minX + w * 0.1, y: rect.maxY - h * 0.25))
        tp.addQuadCurve(to: CGPoint(x: rect.midX + w * 0.15, y: rect.maxY - h * 0.02), control: CGPoint(x: rect.minX + w * 0.1, y: rect.maxY + h * 0.1))
        ctx.stroke(tp, with: .color(col.patch ?? col.ear), style: StrokeStyle(lineWidth: h * 0.18, lineCap: .round))
        // Z（寝ている）
        let z = Text("z").font(.system(size: max(8, size * 0.28), weight: .semibold)).foregroundColor(Ink.onSky)
        ctx.draw(z, at: CGPoint(x: rect.maxX + w * 0.05, y: rect.minY - h * 0.25))
    }

    /// 影の猫の足あと
    static func paws(_ ctx: inout GraphicsContext, at c: CGPoint, size: CGFloat, color: Color) {
        let r = size * 0.5
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.05, width: r * 0.9, height: r * 0.7)), with: .color(color))
        for (dx, dy) in [(-0.55, -0.45), (-0.18, -0.72), (0.18, -0.72), (0.55, -0.45)] as [(CGFloat, CGFloat)] {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + dx * r - r * 0.16, y: c.y + dy * r - r * 0.2, width: r * 0.32, height: r * 0.4)), with: .color(color))
        }
    }
}

enum WalkerPainter {
    /// 旅人（あなた）：生成りのマントとミントの帽子、小さな灯り
    static func draw(_ ctx: inout GraphicsContext, at base: CGPoint, size: CGFloat) {
        let h = size
        ctx.fill(Path(ellipseIn: CGRect(x: base.x - h * 0.22, y: base.y - h * 0.07, width: h * 0.44, height: h * 0.14)), with: .color(Color.black.opacity(0.18)))
        var cloak = Path()
        cloak.move(to: CGPoint(x: base.x - h * 0.2, y: base.y))
        cloak.addLine(to: CGPoint(x: base.x + h * 0.2, y: base.y))
        cloak.addLine(to: CGPoint(x: base.x + h * 0.1, y: base.y - h * 0.52))
        cloak.addLine(to: CGPoint(x: base.x - h * 0.1, y: base.y - h * 0.52))
        cloak.closeSubpath()
        ctx.fill(cloak, with: .color(Ink.panel))
        ctx.stroke(cloak, with: .color(Ink.soft.opacity(0.5)), lineWidth: 0.8)
        let hc = CGPoint(x: base.x, y: base.y - h * 0.64)
        let r = h * 0.15
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x - r, y: hc.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xF2C9A8)))
        var hat = Path()
        hat.move(to: CGPoint(x: hc.x - r * 1.5, y: hc.y - r * 0.4))
        hat.addLine(to: CGPoint(x: hc.x + r * 1.5, y: hc.y - r * 0.4))
        hat.addLine(to: CGPoint(x: hc.x + r * 0.2, y: hc.y - r * 2.4))
        hat.closeSubpath()
        ctx.fill(hat, with: .color(Mint.deep))
        // 灯り
        let lamp = CGPoint(x: base.x + h * 0.24, y: base.y - h * 0.3)
        ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - h * 0.12, y: lamp.y - h * 0.12, width: h * 0.24, height: h * 0.24)), with: .color(Lamp.glow.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - h * 0.05, y: lamp.y - h * 0.05, width: h * 0.1, height: h * 0.1)), with: .color(Lamp.glow))
    }
}

/// 図鑑・結果などで使う、1 匹の猫の絵
struct CatPortrait: View {
    let coat: Coat
    var known = true
    var happy = true
    var tail: Double = 0.4

    var body: some View {
        Canvas { ctx, size in
            let base = CGPoint(x: size.width / 2 - size.width * 0.06, y: size.height * 0.92)
            if known {
                CatPainter.sitting(&ctx, at: base, size: size.height * 0.86, coat: coat, tail: tail, happy: happy)
            } else {
                // まだ会っていない猫：影だけ
                var c = ctx
                c.opacity = 0.35
                CatPainter.peek(&c, at: CGPoint(x: size.width / 2, y: size.height * 0.5), size: size.height * 0.55)
            }
        }
        .accessibilityHidden(true)
    }
}
