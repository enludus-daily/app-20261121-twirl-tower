import SwiftUI

// 見た目のトークン（1 か所で決める）。世界：夕暮れの空に浮かぶ、ありえない形の小さな塔。
// 地は夕暮れの空（ラベンダー → ローズ → アプリコット）、塔はテラコッタ・ミント・砂・すもも色の壁。
// 書体は「建物の銘板」のような横に広い字（.expanded）を見出しと数字に、本文はふつうの字。
// 前日までのアプリ（明朝の淡い 1 色、丸ゴシックの太字、夜の紫と琥珀）と並べて違うこと。

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// RGB を混ぜるための値（面の明るさを向きで変える）
struct RGB: Sendable {
    var r: Double, g: Double, b: Double
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
}

enum Sky {
    static let top = Color(hex: 0x6E5A8E)  // ラベンダーの夕空
    static let middle = Color(hex: 0xC98A8E)  // ローズ
    static let low = Color(hex: 0xF2C49B)  // アプリコットの地平
    static let haze = Color(hex: 0xFBE3C8)
    static let cloud = Color(hex: 0xFFF3E4)
    static let star = Color(hex: 0xFFF6DD)

    static var gradient: LinearGradient {
        LinearGradient(stops: [.init(color: top, location: 0), .init(color: middle, location: 0.52), .init(color: low, location: 1)], startPoint: .top, endPoint: .bottom)
    }
}

/// 紙のパネル・文字・操作（地の夕空の上に浮かぶ札）
enum Ink {
    static let text = Color(hex: 0x34263D)  // すもも色の墨（真っ黒にしない）
    static let soft = Color(hex: 0x6B5A72)
    static let faint = Color(hex: 0x9A8AA0)
    static let panel = Color(hex: 0xFBF1E4)  // 夕日に染まった生成り
    static let panelDeep = Color(hex: 0xF3E2CF)
    static let line = Color(hex: 0xE2CDB8)
    static let onSky = Color(hex: 0xFFF6EA)  // 空の上の文字
    static let onSkySoft = Color(hex: 0xFFF6EA, opacity: 0.78)
}

/// 主な操作：ミント（白い文字が読める濃さは deep）
enum Mint {
    static let accent = Color(hex: 0x8CC9B3)
    static let soft = Color(hex: 0xD6EEE4)
    static let deep = Color(hex: 0x3E8A78)
    static let ledge = Color(hex: 0x2C6A5B)  // ボタンの下の段（石段の厚み）
}

/// 灯り（見つけた猫・光るヒント・灯りの評価）
enum Lamp {
    static let glow = Color(hex: 0xF6CE76)
    static let deep = Color(hex: 0xD99A3C)
    static let soft = Color(hex: 0xFCEBC4)
}

/// 塔の壁（上の面・左の面・右の面の 3 段）
struct Wall: Sendable {
    var top: RGB, left: RGB, right: RGB, trim: RGB

    static func of(_ m: Material) -> Wall {
        switch m {
        case .terracotta: Wall(top: RGB(0xEBA584), left: RGB(0xCD6E52), right: RGB(0xA9543F), trim: RGB(0x8E3F2F))
        case .mint: Wall(top: RGB(0xB7E0CE), left: RGB(0x84BFA8), right: RGB(0x5F9C86), trim: RGB(0x4A7F6C))
        case .sand: Wall(top: RGB(0xF5E6CB), left: RGB(0xDCC6A2), right: RGB(0xBDA47F), trim: RGB(0x9B8462))
        case .plum: Wall(top: RGB(0xB49BC4), left: RGB(0x8E74A2), right: RGB(0x6F5783), trim: RGB(0x56416A))
        }
    }

    static let window = RGB(0x3B2C47)
    static let windowLit = RGB(0xF6CE76)
    static let roof = RGB(0x8E4A3B)
    static let roofLight = RGB(0xB9654E)
    static let wood = RGB(0x7A5236)
}

enum Fonts {
    /// 見出し：銘板のような横に広い字
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold).width(.expanded) }
    static func head(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .system(size: size, weight: .semibold).width(.expanded)
    }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium).width(.expanded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold).width(.expanded).monospacedDigit() }
}

enum Radius {
    static let small: CGFloat = 8
    static let button: CGFloat = 14
    static let card: CGFloat = 20
    /// アーチ窓のパネルの上の丸み
    static let arch: CGFloat = 60
    static let sheet: CGFloat = 28
}

/// 上がアーチ（窓の形）のパネル。塔の窓を札の形にした
struct ArchPanel: Shape {
    var arch: CGFloat = Radius.arch
    var corner: CGFloat = Radius.card

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let a = min(arch, rect.width / 2, rect.height / 2)
        let c = min(corner, rect.height / 4)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + a))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + a), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - c, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - c), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 石段のボタン：押すと段が沈む（下の厚み 4pt がなくなる）
struct StepButtonStyle: ButtonStyle {
    var fill: Color = Mint.deep
    var ledge: Color = Mint.ledge
    var text: Color = .white
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(Fonts.label(14))
            .foregroundStyle(text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: height - 4, maxHeight: height - 4)
            .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(fill))
            .offset(y: pressed ? 3 : 0)
            .background(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous).fill(ledge).offset(y: 4)
            )
            .padding(.bottom, 4)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressed)
    }
}

/// 紙の札のボタン（脇の操作）
struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StepButtonStyle(fill: Ink.panel, ledge: Ink.line, text: Ink.text).makeBody(configuration: configuration)
    }
}

/// 空の上に浮かぶ丸い札（上の小さなボタン）
struct BubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Ink.text)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Ink.panel.opacity(0.92)))
            .overlay(Circle().stroke(Ink.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 夕暮れの空（雲と一番星）。Canvas で部品と同じ大きさに描き、押せる範囲を持たない
struct SkyBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            // 遠い雲（横に長い楕円の重なり）。位置は固定（撮るたびに同じ）
            let clouds: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.62, 1.0), (0.78, 0.55, 0.8), (0.45, 0.78, 1.3), (0.9, 0.86, 0.9), (0.2, 0.9, 0.7)]
            for (x, y, s) in clouds {
                let cx = x * size.width, cy = y * size.height, w = 120 * s
                for (dx, dy, r) in [(-0.35, 0.1, 0.32), (0, 0, 0.42), (0.38, 0.08, 0.3)] as [(CGFloat, CGFloat, CGFloat)] {
                    let rect = CGRect(x: cx + dx * w - r * w, y: cy + dy * w - r * w * 0.45, width: r * w * 2, height: r * w * 0.9)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Sky.cloud.opacity(0.28)))
                }
            }
            // 一番星
            for (x, y, r) in [(0.82, 0.08, 2.2), (0.18, 0.14, 1.4), (0.6, 0.05, 1.2), (0.36, 0.2, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let c = CGPoint(x: x * size.width, y: y * size.height)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Sky.star.opacity(0.9)))
            }
        }
        .background(Sky.gradient)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
