import SwiftUI

@main
struct TwirlTowerApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else {
                PlayView().transition(.opacity)
            }
            if let b = model.banner, model.onboarded {
                VStack {
                    BannerView(banner: b)
                        .padding(.top, 104)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .allowsHitTesting(false)
                .zIndex(10)
                .id(b.id)
            }
        }
        .environment(model)
        // 夕暮れの空の世界を自前の色で描くので、ライトに固定する（ダークでも同じ夕空）
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet, onDismiss: {}) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
                .onDisappear { if sheet == .result { model.resultClosed() } }
        }
        // 手応えの表（README）：押す・回す 90° ごと・止まる・つながる・見つける・足あと・届かない・解いた
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.turnTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.snapTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.8) : nil }
        .sensoryFeedback(trigger: model.connectTick) { _, _ in model.hapticsOn ? .impact(flexibility: .rigid, intensity: 0.7) : nil }
        .sensoryFeedback(trigger: model.findTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.markTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.5) : nil }
        .sensoryFeedback(trigger: model.missTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.completeTick) { _, _ in model.hapticsOn ? .success : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !model.still, !Launch.isDemo else { return }
            // 日付が変わっていたら、今日の塔に入れ替える
            let before = model.today
            model.now = Date()
            if before != model.today, case .daily = model.currentID { model.open(.daily(model.today)) }
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .shelf: ShelfSheet()
        case .book: BookSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        case .result: ResultSheet()
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、今日の塔が毎回同じになるように）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 21, minute: 30)) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["save", "onboarded", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel(persists: false, now: stageDate())
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.still = scene != nil
        model.onboarded = !(scene ?? "").hasPrefix("onboarding")
        model.onboardingPage = scene == "onboarding2" ? 1 : (scene == "onboarding3" ? 2 : 0)
        if scene != "fresh" && !(scene ?? "").hasPrefix("onboarding") && !isDemo {
            model.save = sampleSave(model)
            model.open(.daily(model.today), announce: false)
        }
        return model
    }

    /// 見本：遊んで 5 日目くらい
    static func sampleSave(_ model: AppModel) -> SaveData {
        var s = SaveData()
        for n in 1...5 {
            var p = TowerProgress()
            p.found = Set(0..<5)
            p.done = true
            p.lamps = [3, 2, 3, 3, 2][n - 1]
            p.hints = p.lamps == 3 ? 0 : 2
            s.progress[TowerID.numbered(n).key] = p
            for c in Catalog.catIDs(.numbered(n)) { s.catsFound[c, default: 0] += 1 }
        }
        var p6 = TowerProgress()
        p6.found = [0, 2]
        s.progress[TowerID.numbered(6).key] = p6
        s.streak = 4
        s.bestStreak = 6
        s.lastDaily = model.yesterday
        s.dailyDone = [model.yesterday]
        // 今日の塔：2 匹見つけたところ
        let id = TowerID.daily(model.today)
        let tower = model.tower(id)
        var today = TowerProgress()
        for c in tower.cats where c.kind == .window {
            today.found.insert(c.id)
            today.foundOrder.append(c.id)
            s.catsFound[c.catID, default: 0] += 1
        }
        if let v = tower.cats.first(where: { $0.kind == .window }).flatMap({ tower.views(of: $0).first }) { today.view = v }
        s.progress[id.key] = today
        return s
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(200))
        switch scene {
        case "shelf": model.activeSheet = .shelf
        case "book": model.activeSheet = .book
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "hint":
            _ = model.hunt.nextHint()
            _ = model.hunt.nextHint()
            _ = model.hunt.nextHint()
            if let h = model.hunt.hint { model.hunt.turn(h.view - model.hunt.view); model.snapTo = Double(model.hunt.view) }
            model.showBanner(tr("ヒント 3：光っている", "Hint 3: it's glowing"), tr("光る所をたたこう", "Tap the glow"))
        case "found":
            // 窓の猫を見つけた直後
            model.hunt.progress.found = []
            model.save.progress[model.currentID.key] = model.hunt.progress
            if let c = model.hunt.tower.cats.first(where: { $0.kind == .window }), let v = model.hunt.tower.views(of: c).first {
                model.hunt.turn(v - model.hunt.view)
                model.snapTo = Double(model.hunt.view)
                model.tapCat(c.id)
                model.popStart = [:]
            }
        case "shadow":
            if let c = model.hunt.tower.cats.first(where: { $0.kind == .shadow }) {
                model.hunt.turn(c.marks[0] - model.hunt.view)
                model.snapTo = Double(model.hunt.view)
                model.tapCat(c.id)
            }
        case "result":
            model.hunt.progress.found = Set(0..<5)
            model.hunt.progress.done = true
            model.hunt.progress.lamps = 3
            model.lastCompleted = model.currentID
            model.save.streak = 5
            model.save.lastDaily = model.today
            model.activeSheet = .result
        case "empty":
            model.save = SaveData()
            model.activeSheet = .book
        case "pro":
            model.proOverride = true
            model.open(.numbered(20), announce: false)
        case "onboarding2", "onboarding3":
            break
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 今日の塔 → 回して窓の猫 → 錯視の道を渡って屋上の猫 → 影の足あと 2 つ
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        await wait(1.4)
        let tower = model.hunt.tower
        // 窓の猫
        if let c = tower.cats.first(where: { $0.kind == .window }), let v = tower.views(of: c).first {
            await turn(model, to: v)
            await wait(0.6)
            model.tapCat(c.id)
            await wait(1.6)
        }
        // 屋上の猫（錯視の道）
        if let c = tower.cats.first(where: { $0.kind == .roof }), let goal = c.top,
           let route = model.hunt.walker.route(from: model.hunt.at, view: model.hunt.view, to: goal) {
            var i = 1
            while i < route.count {
                let s = route[i]
                if s.view != model.hunt.view {
                    await turn(model, to: s.view)
                    await wait(0.7)
                    i += 1
                    continue
                }
                // 同じ向きで続く所までまとめて歩く
                var j = i
                while j + 1 < route.count, route[j + 1].view == s.view { j += 1 }
                model.walk(to: route[j].top)
                await wait(Double(j - i + 1) * 0.23 + 0.5)
                i = j + 1
            }
            await wait(1.2)
        }
        // 影の猫
        if let c = tower.cats.first(where: { $0.kind == .shadow }) {
            for v in c.marks {
                await turn(model, to: v)
                await wait(0.6)
                model.tapCat(c.id)
                await wait(1.0)
            }
        }
    }

    private static func turn(_ model: AppModel, to v: Int) async {
        let d = Hunt.turns(from: model.hunt.view, to: v)
        if d == 2 {
            model.turn(1)
            try? await Task.sleep(for: .milliseconds(450))
            model.turn(1)
        } else if d != 0 {
            model.turn(d)
        }
    }
}
