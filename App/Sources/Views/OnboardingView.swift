import SwiftUI

/// 角度を動きでつなぐ塔の絵（案内の見本で使う）
struct TurningTowerArt: View, Animatable {
    let tower: Tower
    var angle: Double
    var found: Set<Int> = []
    var reachable: Set<Top> = []
    var glow: [Top: Double] = [:]
    var showWalker = false

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let snapped = abs(angle - angle.rounded()) < 0.001 ? ((Int(angle.rounded()) % 4) + 4) % 4 : nil
        var s = ArtState(angle: angle, snapped: snapped, found: found)
        s.walker = tower.start
        s.reachable = snapped == nil ? [] : reachable
        s.glow = glow
        s.showWalker = showWalker
        s.still = true
        s.wag = 0.6
        return TowerArt(tower: tower, state: s, padding: 10, maxScale: 46)
    }
}

/// はじめの案内（3 ページ）：回す → つながる → 5 匹を探す
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var angle = 0.0
    @State private var spin: Task<Void, Never>?

    private let tower = Catalog.tower(.numbered(1))

    var body: some View {
        ZStack {
            SkyBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: tr("まわる塔とかくれ猫", "Twirl Tower: Hidden Cats"))
                        .font(Fonts.label(12)).kerning(1).foregroundStyle(Ink.onSkySoft)
                    Spacer()
                    Button(tr("とばす", "Skip")) { model.finishOnboarding() }
                        .font(Fonts.label(13)).foregroundStyle(Ink.onSky)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 20)
                illustration
                    .frame(maxHeight: .infinity)
                    .id(page)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: titles[page]).font(Fonts.title(22)).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: bodies[page]).font(Fonts.body(15)).foregroundStyle(Ink.soft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(i == page ? Mint.deep : Ink.line).frame(width: i == page ? 22 : 8, height: 8)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .frame(maxWidth: 560, alignment: .leading)
                .background(ArchPanel(arch: 90).fill(Ink.panel))
                .padding(.horizontal, 16)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if page < 2 {
                        Button(tr("次へ", "Next")) { next() }
                            .buttonStyle(StepButtonStyle())
                            .accessibilityIdentifier("main.onboardNext")
                    } else {
                        Button(tr("塔へ行く", "Go to the tower")) { model.finishOnboarding() }
                            .buttonStyle(StepButtonStyle())
                            .accessibilityIdentifier("main.onboardStart")
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            page = model.onboardingPage
            startSpin()
        }
        .onDisappear { spin?.cancel() }
    }

    private var titles: [String] {
        [tr("塔を回すと、見え方が変わる", "Turn the tower, change the view"),
         tr("隣り合って見えた床は、つながる", "If floors look connected, they are"),
         tr("5 匹の猫を探そう", "Find all 5 cats")]
    }

    private var bodies: [String] {
        [tr("指でドラッグすると、空に浮かぶ塔が回る。はなすと 90° ごとに、すっと止まる。", "Drag to spin the floating tower. Let go and it snaps every 90°."),
         tr("本当は離れた床も、この向きでつながって見えれば歩いて渡れる。向きを変えると、道が変わる。", "Even far-apart floors can be crossed when they line up on screen. Each side opens different paths."),
         tr("窓の中の光る目、道の先の屋上、2 つの向きの足あと。毎日ちがう塔がひとつ届く。記録は端末の中だけ。", "Glowing eyes in windows, rooftops down the path, paw prints seen from two sides. A new tower every day. Progress stays on your device.")]
    }

    @ViewBuilder private var illustration: some View {
        switch page {
        case 0:
            TurningTowerArt(tower: tower, angle: angle)
        case 1:
            let v = illusionView
            let w = Walker(tower: tower)
            TurningTowerArt(tower: tower, angle: Double(v), reachable: w.reachable(from: tower.start, view: v), glow: illusionGlow(v), showWalker: true)
        default:
            TurningTowerArt(tower: tower, angle: angle, found: Set(0..<5))
        }
    }

    /// 錯視の道が一番多く見える向き
    private var illusionView: Int {
        (0..<4).max { illusions($0).count < illusions($1).count } ?? 0
    }

    private func illusions(_ v: Int) -> [Top] {
        let vis = tower.visibleTops(view: v)
        let r = Walker(tower: tower).reachable(from: tower.start, view: v)
        return r.filter { t in tower.screenNeighbors(t, view: v, visible: vis).contains { tower.isIllusion(t, $0) } }
    }

    private func illusionGlow(_ v: Int) -> [Top: Double] {
        Dictionary(uniqueKeysWithValues: illusions(v).map { ($0, 0.9) })
    }

    private func next() {
        model.press()
        withAnimation(.easeOut(duration: 0.3)) { page = min(2, page + 1) }
    }

    /// 見本の塔をゆっくり回す（撮影・動きを減らす設定では止める）
    private func startSpin() {
        guard !model.still, !model.reduceMotion else { return }
        spin = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1700))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { angle += 1 }
            }
        }
    }
}
