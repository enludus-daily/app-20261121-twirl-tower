import StoreKit
import SwiftUI
import UIKit

/// シートの上の見出し（閉じるボタンつき）
struct SheetHeader: View {
    let title: String
    var subtitle: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title).font(Fonts.title(22)).foregroundStyle(Ink.text)
                if let subtitle {
                    Text(verbatim: subtitle).font(Fonts.body(13)).foregroundStyle(Ink.soft)
                }
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(BubbleButtonStyle())
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier("main.close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - 塔の棚

struct ShelfSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: tr("塔の棚", "Tower shelf"), subtitle: trf("解いた塔 %d ・ 図鑑 %d / 40", "%d towers solved · %d / 40 cats", model.save.towersDone, model.save.catsKnown))
                todayCard.padding(.horizontal, 20)
                section(tr("塔をめぐる", "The towers"))
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...Catalog.towerCount, id: \.self) { n in
                        TowerTile(id: .numbered(n), number: n) { choose(.numbered(n)) }
                    }
                }
                .padding(.horizontal, 20)
                section(tr("過去の今日の塔（Pro）", "Past daily towers (Pro)"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.pastDays, id: \.self) { d in
                            TowerTile(id: .daily(d), number: nil) { choose(.daily(d)) }
                                .frame(width: 104)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Ink.panel.ignoresSafeArea())
    }

    private var todayCard: some View {
        let id = TowerID.daily(model.today)
        return Button { choose(id) } label: {
            HStack(spacing: 14) {
                TowerArt(tower: model.tower(id), state: ArtState(angle: 0.5, snapped: nil, showWalker: false, still: true), padding: 6, maxScale: 20)
                    .frame(width: 96, height: 96)
                    .background(ArchPanel(arch: 40, corner: 12).fill(Sky.gradient))
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: Catalog.name(id)).font(Fonts.head(16)).foregroundStyle(Ink.text)
                    Text(verbatim: model.isDone(id) ? tr("今日の塔は解いた。また明日", "Solved today. A new one tomorrow") : trf("猫 %d / 5 ・ 毎日ちがう塔", "Cats %d / 5 · a new tower every day", model.catsFound(in: id)))
                        .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                    Text(verbatim: model.streak > 0 ? trf("%d 日つづけて解いている（最長 %d 日）", "%d-day streak (best %d)", model.streak, model.save.bestStreak) : tr("今日から、また 1 日目", "Day one starts today"))
                        .font(Fonts.label(11)).kerning(0.4).foregroundStyle(Mint.deep)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Ink.panelDeep))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shelf.today")
    }

    private func section(_ t: String) -> some View {
        Text(verbatim: t).font(Fonts.label(12)).kerning(0.8).foregroundStyle(Ink.soft).padding(.horizontal, 20)
    }

    private func choose(_ id: TowerID) {
        model.press()
        if model.canPlay(id) {
            model.open(id)
            dismiss()
        } else {
            model.activeSheet = .paywall
        }
    }
}

/// 棚の 1 つの塔（ミニチュア）
struct TowerTile: View {
    @Environment(AppModel.self) private var model
    let id: TowerID
    let number: Int?
    let action: () -> Void

    var body: some View {
        let locked = !model.canPlay(id)
        let done = model.isDone(id)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    TowerArt(tower: model.tower(id), state: ArtState(angle: 0.5, snapped: nil, found: done ? Set(0..<5) : [], showWalker: false, still: true), padding: 6, maxScale: 16)
                        .frame(height: 92)
                        .background(ArchPanel(arch: 36, corner: 10).fill(done ? AnyShapeStyle(Sky.gradient) : AnyShapeStyle(Ink.panelDeep)))
                        .opacity(locked ? 0.45 : 1)
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Ink.soft).padding(8)
                    } else if number == Catalog.trialTower, !model.isPro {
                        Text(verbatim: tr("おためし", "Try")).font(Fonts.label(9)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Mint.deep)).padding(6)
                    }
                }
                Text(verbatim: title).font(Fonts.label(11)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    if done {
                        ForEach(0..<3, id: \.self) { i in
                            Circle().fill(i < model.lamps(id) ? Lamp.glow : Ink.line).frame(width: 7, height: 7)
                        }
                    } else {
                        Text(verbatim: trf("%d / 5", "%d / 5", model.catsFound(in: id))).font(Fonts.number(10)).foregroundStyle(Ink.faint)
                    }
                }
                .frame(height: 10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + (locked ? tr("（Pro）", " (Pro)") : ""))
    }

    private var title: String {
        if let number { return "\(number). " + Catalog.info(number).name.text }
        if case .daily(let d) = id {
            let p = d.split(separator: "-")
            return p.count == 3 ? "\(Int(p[1]) ?? 0)/\(Int(p[2]) ?? 0)" : d
        }
        return ""
    }
}

// MARK: - 猫図鑑

struct BookSheet: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: tr("猫図鑑", "Cat book"), subtitle: trf("会えた猫 %d / 40", "%d / 40 cats met", model.save.catsKnown))
                if model.save.catsKnown == 0 {
                    Text(verbatim: tr("まだ 1 匹も会っていない。塔を回して、窓の中の光る目を探そう。", "No cats yet. Turn a tower and look for glowing eyes in the windows."))
                        .font(Fonts.body(14)).foregroundStyle(Ink.soft)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Ink.panelDeep))
                        .padding(.horizontal, 20)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Catalog.cats) { cat in
                        CatCard(cat: cat, count: model.save.catsFound[cat.id] ?? 0)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
        .background(Ink.panel.ignoresSafeArea())
    }
}

struct CatCard: View {
    let cat: CatInfo
    let count: Int

    var body: some View {
        let known = count > 0
        VStack(alignment: .leading, spacing: 6) {
            CatPortrait(coat: cat.coat, known: known)
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .background(ArchPanel(arch: 50, corner: 10).fill(known ? AnyShapeStyle(Sky.gradient) : AnyShapeStyle(Ink.panelDeep)))
            Text(verbatim: known ? cat.name.text : "？？？").font(Fonts.head(13)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
            if known {
                Text(verbatim: trf("好物：%@", "Loves: %@", cat.food.text)).font(Fonts.body(11)).foregroundStyle(Ink.soft).lineLimit(2)
                Text(verbatim: cat.quirk.text).font(Fonts.body(11)).foregroundStyle(Ink.faint).lineLimit(2)
                Text(verbatim: trf("会えた回数 %d", "Times met: %d", count)).font(Fonts.number(10)).foregroundStyle(Mint.deep)
            } else {
                Text(verbatim: cat.rare ? tr("Pro の塔にだけいる珍しい猫", "A rare cat found only in Pro towers") : tr("どこかの塔にいる", "Hiding in some tower"))
                    .font(Fonts.body(11)).foregroundStyle(Ink.faint).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 190, alignment: .top)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.white.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Ink.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 結果

struct ResultSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var shown = 0

    var body: some View {
        let id = model.lastCompleted ?? model.currentID
        let tower = model.tower(id)
        let progress = id == model.currentID ? model.hunt.progress : model.save.progress(id)
        ScrollView {
            VStack(spacing: 16) {
                Text(verbatim: tr("塔を解いた", "Tower solved"))
                    .font(Fonts.label(12)).kerning(1.2).foregroundStyle(Ink.onSkySoft)
                    .padding(.top, 28)
                Text(verbatim: Catalog.name(id)).font(Fonts.title(26)).foregroundStyle(Ink.onSky).multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        LampIcon(lit: i < progress.lamps && i < shown)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trf("灯り %d / 3", "Lamps %d / 3", progress.lamps))
                Text(verbatim: progress.hints == 0 ? tr("ヒントなしで 5 匹", "All 5 without hints") : trf("ヒント %d 回", "%d hints used", progress.hints))
                    .font(Fonts.body(13)).foregroundStyle(Ink.onSkySoft)
                TowerArt(tower: tower, state: ArtState(angle: Double(progress.view), snapped: progress.view, found: Set(0..<5), wag: 0.6, showWalker: false, still: true), padding: 10, maxScale: 40)
                    .frame(height: 220)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tower.cats) { c in
                        let info = Catalog.cats[c.catID]
                        HStack(spacing: 10) {
                            CatPortrait(coat: info.coat).frame(width: 36, height: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: info.name.text).font(Fonts.head(13)).foregroundStyle(Ink.text)
                                Text(verbatim: trf("好物：%@", "Loves: %@", info.food.text)).font(Fonts.body(11)).foregroundStyle(Ink.soft)
                            }
                            Spacer()
                            if info.rare {
                                Text(verbatim: tr("珍しい", "Rare")).font(Fonts.label(9)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(Color(hex: 0x8E74A2)))
                            }
                        }
                    }
                }
                .padding(16)
                .background(ArchPanel(arch: 40).fill(Ink.panel))
                .padding(.horizontal, 20)
                if case .daily = id {
                    Text(verbatim: model.streak > 0 ? trf("%d 日つづけて解いた。明日はまた別の塔", "%d days in a row. A new tower tomorrow", model.streak) : tr("明日はまた別の塔", "A new tower tomorrow"))
                        .font(Fonts.body(13)).foregroundStyle(Ink.onSky)
                }
                ShareLink(item: shareImage(tower: tower, progress: progress, id: id), preview: SharePreview(Catalog.name(id), image: shareImage(tower: tower, progress: progress, id: id))) {
                    Label(tr("塔の絵を共有", "Share the tower"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(TagButtonStyle())
                .padding(.horizontal, 20)
                Button {
                    dismiss()
                } label: {
                    Text(verbatim: tr("棚へ（次の塔をえらぶ）", "To the shelf (pick the next tower)"))
                }
                .buttonStyle(StepButtonStyle())
                .padding(.horizontal, 20)
                .accessibilityIdentifier("result.next")
            }
            .padding(.bottom, 30)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(SkyBackdrop().ignoresSafeArea())
        .task {
            // 灯りを 1 つずつ（動きを減らす設定ではまとめて）
            if model.motionOff || model.still {
                shown = 3
                return
            }
            for i in 1...3 {
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shown = i }
            }
        }
    }

    @MainActor
    private func shareImage(tower: Tower, progress: TowerProgress, id: TowerID) -> Image {
        let card = ShareCard(tower: tower, title: Catalog.name(id), lamps: progress.lamps)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage { return Image(uiImage: ui) }
        return Image(systemName: "photo")
    }
}

/// 共有の絵（360×480）
struct ShareCard: View {
    let tower: Tower
    let title: String
    let lamps: Int

    var body: some View {
        VStack(spacing: 10) {
            Text(verbatim: tr("まわる塔とかくれ猫", "Twirl Tower: Hidden Cats")).font(Fonts.label(11)).kerning(1).foregroundStyle(Ink.onSkySoft)
            Text(verbatim: title).font(Fonts.title(22)).foregroundStyle(Ink.onSky)
            TowerArt(tower: tower, state: ArtState(angle: 0, snapped: 0, found: Set(0..<5), wag: 0.6, showWalker: false, still: true), padding: 8, maxScale: 40)
                .frame(height: 320)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in LampIcon(lit: i < lamps).scaleEffect(0.7) }
            }
        }
        .padding(20)
        .frame(width: 360, height: 480)
        .background(SkyBackdrop())
    }
}

/// 灯り（評価）
struct LampIcon: View {
    let lit: Bool

    var body: some View {
        ZStack {
            if lit {
                Circle().fill(Lamp.glow.opacity(0.35)).frame(width: 46, height: 46)
            }
            // 吊りランタン：取っ手・笠・ガラス・台
            Circle().trim(from: 0.5, to: 1).stroke(lit ? Lamp.deep : Ink.onSkySoft, lineWidth: 1.5).frame(width: 10, height: 10).offset(y: -19)
            Path { p in
                p.move(to: CGPoint(x: 5, y: 6)); p.addLine(to: CGPoint(x: 23, y: 6)); p.addLine(to: CGPoint(x: 14, y: 0)); p.closeSubpath()
            }
            .fill(lit ? Lamp.deep : Ink.onSkySoft)
            .frame(width: 28, height: 6)
            .offset(y: -13)
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(lit ? Lamp.glow : Ink.panel.opacity(0.35)).frame(width: 18, height: 20)
            RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(lit ? Lamp.deep : Ink.onSkySoft, lineWidth: 1.5).frame(width: 18, height: 20)
            Rectangle().fill(lit ? Lamp.deep : Ink.onSkySoft).frame(width: 1.5, height: 20)
            Capsule().fill(lit ? Lamp.deep : Ink.onSkySoft).frame(width: 22, height: 4).offset(y: 12)
        }
        .frame(width: 46, height: 46)
        .scaleEffect(lit ? 1 : 0.85)
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: tr("設定", "Settings"))
                group(tr("音と振動", "Sound & haptics")) {
                    Toggle(tr("効果音", "Sound effects"), isOn: Binding(get: { model.soundOn }, set: { model.setSound($0) }))
                    Toggle(tr("振動", "Haptics"), isOn: Binding(get: { model.hapticsOn }, set: { model.setHaptics($0) }))
                }
                group(tr("遊び方", "How to play")) {
                    VStack(alignment: .leading, spacing: 8) {
                        rule("arrow.left.and.right", tr("塔をドラッグすると回る。指をはなすと 90° ごとに止まる。", "Drag the tower to turn it. It snaps every 90°."))
                        rule("point.topleft.down.to.point.bottomright.curvepath", tr("画面で隣り合って見えた床は、つながる。床をたたくと歩く。", "Floors that look connected are connected. Tap a floor to walk."))
                        rule("window.vertical.closed", tr("窓の猫は、見える向きでたたく。屋上の猫は歩いて会いに行く。", "Tap window cats from the side they show. Walk up to rooftop cats."))
                        rule("pawprint.fill", tr("影の猫は、2 つの向きで足あとをたたくと現れる。", "Shadow cats appear after you tap their prints from two sides."))
                    }
                    Button(tr("はじめの案内をもう一度見る", "Show the intro again")) {
                        model.activeSheet = nil
                        model.onboarded = false
                        model.persist()
                    }
                    .foregroundStyle(Mint.deep)
                }
                group("Pro") {
                    if model.isPro {
                        Text(verbatim: tr("Pro を使っている。ありがとう！", "You have Pro. Thank you!")).foregroundStyle(Ink.text)
                    } else {
                        Button(tr("Pro を見る", "See Pro")) { model.activeSheet = .paywall }.foregroundStyle(Mint.deep)
                    }
                    Button(tr("購入を復元", "Restore purchase")) { Task { await model.purchases.restore() } }
                        .foregroundStyle(Mint.deep)
                }
                group(tr("プライバシー", "Privacy")) {
                    Text(verbatim: tr("記録は端末の中だけに残る。通信・広告・解析はしない。", "Your progress stays on this device. No network, ads, or analytics."))
                        .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                }
                Text(verbatim: trf("バージョン %@", "Version %@", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                    .font(Fonts.label(11)).foregroundStyle(Ink.faint).padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
        }
        .tint(Mint.deep)
        .background(Ink.panel.ignoresSafeArea())
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(Mint.deep)
            Text(verbatim: text).font(Fonts.body(13)).foregroundStyle(Ink.text)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title).font(Fonts.label(12)).kerning(0.8).foregroundStyle(Ink.soft)
            content().font(Fonts.body(15))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.white.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Ink.line, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

// MARK: - Pro（課金の画面）

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var buying = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SheetHeader(title: "Pro", subtitle: tr("1 回の購入で、ずっと", "One purchase, forever"))
                HStack(spacing: -18) {
                    ForEach([10, 9, 11], id: \.self) { n in
                        TowerArt(tower: model.tower(.numbered(n)), state: ArtState(angle: 0.5, snapped: nil, showWalker: false, still: true), padding: 4, maxScale: 14)
                            .frame(width: 100, height: 110)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(ArchPanel(arch: 70).fill(Sky.gradient))
                .padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 14) {
                    benefit("building.columns", tr("塔が 28 つ増える", "28 more towers"), tr("灯台・時計台・温室・天文台…大きく高く、橋の多い塔", "Lighthouse, clock tower, greenhouse, observatory… taller towers with more bridges"))
                    benefit("pawprint", tr("珍しい猫 16 匹", "16 rare cats"), tr("Pro の塔にだけいる猫。図鑑が 40 匹そろう", "Cats that live only in Pro towers. Complete all 40"))
                    benefit("calendar", tr("過去 14 日の今日の塔", "The last 14 daily towers"), tr("見のがした日の塔を、あとから遊べる", "Play the days you missed"))
                    benefit("gift", tr("先に 1 つ試せる", "Try one first"), trf("棚の %d 番「%@」は無料で遊べる", "Tower %d, “%@”, is free to try", Catalog.trialTower, Catalog.info(Catalog.trialTower).name.text))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.white.opacity(0.6)))
                .padding(.horizontal, 20)
                if model.isPro {
                    Text(verbatim: tr("Pro を使っている。ありがとう！", "You have Pro. Thank you!")).font(Fonts.head(15)).foregroundStyle(Mint.deep)
                } else {
                    buyButton.padding(.horizontal, 20)
                }
                if let message {
                    Text(verbatim: message).font(Fonts.body(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.center).padding(.horizontal, 20)
                }
                Button(tr("購入を復元", "Restore purchase")) {
                    Task {
                        await model.purchases.restore()
                        message = model.isPro ? tr("復元した", "Restored") : tr("復元できる購入はなかった", "No purchase to restore")
                    }
                }
                .font(Fonts.body(14)).foregroundStyle(Mint.deep)
                .accessibilityIdentifier("paywall.restore")
                Text(verbatim: tr("買い切り（サブスクではない）。家族共有に対応。ヒントはずっと無料。", "One-time purchase, not a subscription. Family Sharing supported. Hints are always free."))
                    .font(Fonts.body(11)).foregroundStyle(Ink.faint).multilineTextAlignment(.center).padding(.horizontal, 24)
            }
            .padding(.bottom, 30)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.panel.ignoresSafeArea())
        .task { if model.purchases.loadState == .idle { await model.purchases.load() } }
    }

    @ViewBuilder private var buyButton: some View {
        let product = model.purchases.products.first
        let price = product?.displayPrice ?? (model.still ? "¥480" : nil)
        if let price {
            Button {
                guard let product, !buying else { return }
                buying = true
                Task {
                    let r = await model.purchases.purchase(product)
                    buying = false
                    switch r {
                    case .purchased: message = tr("ありがとう！ Pro の塔が棚に並んだ", "Thank you! Pro towers are on the shelf"); model.press()
                    case .pending: message = tr("承認を待っている", "Waiting for approval")
                    case .cancelled: message = nil
                    case .failed: message = tr("購入できなかった。時間をおいて試してほしい", "The purchase didn't go through. Please try again later")
                    }
                }
            } label: {
                Text(verbatim: buying ? tr("購入中…", "Purchasing…") : trf("Pro にする %@", "Get Pro %@", price))
            }
            .buttonStyle(StepButtonStyle())
            .accessibilityIdentifier("paywall.buy")
        } else if model.purchases.loadState == .loading || model.purchases.loadState == .idle {
            ProgressView().tint(Mint.deep).frame(height: 52)
        } else {
            VStack(spacing: 8) {
                Text(verbatim: tr("いまは購入できない。通信できる所で開き直してほしい", "Purchases aren't available right now. Try again with a connection"))
                    .font(Fonts.body(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                Button(tr("もう一度読み込む", "Reload")) { Task { await model.purchases.load() } }
                    .font(Fonts.body(14)).foregroundStyle(Mint.deep)
            }
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Mint.deep).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(Fonts.head(14)).foregroundStyle(Ink.text)
                Text(verbatim: detail).font(Fonts.body(12)).foregroundStyle(Ink.soft)
            }
        }
    }
}
