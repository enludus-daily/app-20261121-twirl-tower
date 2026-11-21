import SwiftUI

/// 遊ぶ画面：夕空に浮かぶ塔を回し、歩き、猫を見つける。
/// 普通の iPhone・Duo の外側（compact）は縦に、Duo の内側（regular）は塔を大きく・横に猫の一覧
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            SkyBackdrop().ignoresSafeArea()
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        header
                        stage
                    }
                    SidePanel()
                        .frame(width: 330)
                        .padding(.vertical, 16)
                        .padding(.trailing, 16)
                }
                .safeAreaInset(edge: .bottom) { controls.frame(maxWidth: 560) }
            } else {
                VStack(spacing: 0) {
                    header
                    stage
                }
                .safeAreaInset(edge: .bottom) { controls }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { model.press(); model.activeSheet = .shelf } label: { Image(systemName: "square.grid.2x2") }
                    .buttonStyle(BubbleButtonStyle())
                    .accessibilityLabel(tr("塔の棚", "Tower shelf"))
                    .accessibilityIdentifier("main.shelf")
                Spacer(minLength: 4)
                VStack(spacing: 2) {
                    Text(verbatim: Catalog.name(model.currentID))
                        .font(Fonts.title(17))
                        .foregroundStyle(Ink.onSky)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if model.streak > 0 {
                        Text(verbatim: trf("%d 日つづけて", "%d-day streak", model.streak))
                            .font(Fonts.label(11))
                            .kerning(0.6)
                            .foregroundStyle(Ink.onSkySoft)
                    }
                }
                Spacer(minLength: 4)
                Button { model.press(); model.activeSheet = .book } label: { Image(systemName: "pawprint") }
                    .buttonStyle(BubbleButtonStyle())
                    .accessibilityLabel(tr("猫図鑑", "Cat book"))
                    .accessibilityIdentifier("main.book")
                Button { model.press(); model.activeSheet = .settings } label: { Image(systemName: "gearshape") }
                    .buttonStyle(BubbleButtonStyle())
                    .accessibilityLabel(tr("設定", "Settings"))
                    .accessibilityIdentifier("main.settings")
            }
            CatDots()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var stage: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !model.animating(at: Date()))) { tl in
            let _ = model.frameTick
            GeometryReader { geo in
                let state = model.artState(at: tl.date)
                TowerArt(tower: model.hunt.tower, state: state, padding: 28, maxScale: sizeClass == .regular ? 90 : 64)
                    .offset(x: model.shakeOffset(at: tl.date))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if abs(v.translation.width) > 8 || model.dragAngle != nil { model.dragChanged(v.translation.width) }
                            }
                            .onEnded { v in
                                if model.dragAngle != nil {
                                    model.dragEnded(predicted: v.predictedEndTranslation.width)
                                } else if hypot(v.translation.width, v.translation.height) < 10 {
                                    let (s, o) = Projection.fit(model.hunt.tower, in: geo.size, padding: 28, maxScale: sizeClass == .regular ? 90 : 64)
                                    let p = Projection(tower: model.hunt.tower, angle: Double(model.hunt.view), scale: s, origin: o)
                                    model.tap(TowerPainter(tower: model.hunt.tower, proj: p, state: state).hit(v.location))
                                }
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel(towerLabel)
                    .accessibilityAddTraits(.allowsDirectInteraction)
            }
        }
    }

    private var towerLabel: String {
        let n = model.hunt.progress.found.count
        let side = [tr("正面", "front"), tr("左の面", "left side"), tr("裏", "back"), tr("右の面", "right side")][model.hunt.view]
        return trf("塔。いまは%@から見ている。猫 %d / 5", "The tower, seen from the %@. Cats %d / 5", side, n)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { model.turn(-1) } label: {
                Label(tr("右へ", "Right"), systemImage: "arrow.uturn.right")
            }
            .buttonStyle(TagButtonStyle())
            .accessibilityLabel(tr("右へ回す", "Turn right"))
            .accessibilityIdentifier("main.turnRight")
            Button { model.askHint() } label: {
                Label(hintTitle, systemImage: "lightbulb")
            }
            .buttonStyle(StepButtonStyle())
            .accessibilityIdentifier("main.hint")
            Button { model.turn(1) } label: {
                Label(tr("左へ", "Left"), systemImage: "arrow.uturn.left")
            }
            .buttonStyle(TagButtonStyle())
            .accessibilityLabel(tr("左へ回す", "Turn left"))
            .accessibilityIdentifier("main.turnLeft")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var hintTitle: String {
        guard let h = model.hunt.hint else { return tr("ヒント", "Hint") }
        return trf("ヒント %d/3", "Hint %d/3", h.level)
    }
}

/// 5 匹の進み具合（灯りの丸）
struct CatDots: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            ForEach(model.hunt.tower.cats) { c in
                let got = model.hunt.progress.found.contains(c.id)
                ZStack {
                    Circle().fill(got ? Lamp.glow : Ink.panel.opacity(0.25))
                    Circle().stroke(got ? Lamp.deep : Ink.onSkySoft, lineWidth: 1)
                    Image(systemName: icon(c.kind))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(got ? Ink.text : Ink.onSky)
                }
                .frame(width: 28, height: 28)
                .scaleEffect(got ? 1 : 0.9)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: got)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("見つけた猫 %d / 5", "Cats found %d / 5", model.hunt.progress.found.count))
    }

    private func icon(_ k: CatKind) -> String {
        switch k {
        case .window: "window.vertical.closed"
        case .roof: "point.topleft.down.to.point.bottomright.curvepath"
        case .shadow: "pawprint.fill"
        }
    }
}

/// Duo の内側：見つけた猫の一覧と、今日の塔
struct SidePanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: tr("この塔の猫", "Cats in this tower"))
                .font(Fonts.head(15))
                .foregroundStyle(Ink.text)
                .padding(.top, 34)
            ForEach(model.hunt.tower.cats) { c in
                let got = model.hunt.progress.found.contains(c.id)
                let info = Catalog.cats[c.catID]
                HStack(spacing: 10) {
                    CatPortrait(coat: info.coat, known: got)
                        .frame(width: 40, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: got ? info.name.text : tr("まだ見つけていない", "Not found yet"))
                            .font(Fonts.body(14).weight(.medium))
                            .foregroundStyle(got ? Ink.text : Ink.faint)
                        Text(verbatim: kindText(c.kind))
                            .font(Fonts.label(11))
                            .foregroundStyle(Ink.soft)
                    }
                    Spacer()
                }
            }
            Spacer()
            Text(verbatim: tr("画面で隣り合って見えた床は、つながる。", "Floors that look connected are connected."))
                .font(Fonts.body(13))
                .foregroundStyle(Ink.soft)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(ArchPanel(arch: 80).fill(Ink.panel.opacity(0.94)))
    }

    private func kindText(_ k: CatKind) -> String {
        switch k {
        case .window: tr("窓の猫", "Window cat")
        case .roof: tr("道の先の猫", "Rooftop cat")
        case .shadow: tr("影の猫", "Shadow cat")
        }
    }
}

/// 上に出る知らせ（押せる範囲を持たない）
struct BannerView: View {
    let banner: Banner

    var body: some View {
        HStack(spacing: 10) {
            if banner.lamp {
                Circle().fill(Lamp.glow).frame(width: 10, height: 10)
                    .shadow(color: Lamp.glow, radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: banner.title).font(Fonts.head(14)).foregroundStyle(Ink.text)
                Text(verbatim: banner.detail).font(Fonts.body(12)).foregroundStyle(Ink.soft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Ink.panel))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Ink.line, lineWidth: 1))
        .shadow(color: Color(hex: 0x34263D).opacity(0.18), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
