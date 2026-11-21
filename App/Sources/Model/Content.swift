import Foundation

/// 日本語と英語の組（手で用意した中身）。scripts/gen-strings.py が T(...) も String Catalog に入れる
struct T: Hashable, Sendable {
    let ja: String
    let en: String
    init(_ ja: String, _ en: String) { self.ja = ja; self.en = en }
    var text: String { Lang.isJapanese ? ja : en }
}

/// 毛の模様
enum Coat: Int, Codable, Sendable, CaseIterable {
    case ginger, black, white, gray, calico, tuxedo, cream, tabby, siamese, smoke
}

struct CatInfo: Identifiable, Sendable {
    let id: Int
    let name: T
    let coat: Coat
    let food: T
    let quirk: T
    /// Pro の塔だけに出る珍しい猫
    var rare: Bool { id >= Catalog.commonCats }
}

/// 塔の呼び名（棚の番号の塔と、毎日の塔）
enum TowerID: Hashable, Codable, Sendable {
    case numbered(Int)  // 1〜36
    case daily(String)  // "2026-11-21"

    var key: String {
        switch self {
        case .numbered(let n): "t\(n)"
        case .daily(let d): "d\(d)"
        }
    }
}

struct TowerInfo: Sendable {
    let number: Int
    let name: T
    let recipe: TowerRecipe
}

enum Catalog {
    static let commonCats = 24
    static let freeTowers = 8
    /// Pro の塔を 1 つだけ、買う前に遊べる
    static let trialTower = 9

    // MARK: 猫図鑑（40 匹）

    static let cats: [CatInfo] = [
        CatInfo(id: 0, name: T("こむぎ", "Wheat"), coat: .ginger, food: T("焼きたてのパンの耳", "Warm bread crusts"), quirk: T("屋上の日だまりから動かない", "Never leaves the sunny rooftop")),
        CatInfo(id: 1, name: T("すみ", "Inky"), coat: .black, food: T("いわしの干物", "Dried sardines"), quirk: T("窓の影にまぎれるのが得意", "Blends into window shadows")),
        CatInfo(id: 2, name: T("ましろ", "Snow"), coat: .white, food: T("ミルクのあわ", "Milk foam"), quirk: T("カーテンのふりをする", "Pretends to be a curtain")),
        CatInfo(id: 3, name: T("ねずみ色のトト", "Toto"), coat: .gray, food: T("ゆでたささみ", "Poached chicken"), quirk: T("はしごの上で寝る", "Naps on top of ladders")),
        CatInfo(id: 4, name: T("みけ", "Patches"), coat: .calico, food: T("かつおぶし", "Bonito flakes"), quirk: T("3 つの色の窓が好き", "Loves three-colored windows")),
        CatInfo(id: 5, name: T("タキシード", "Tux"), coat: .tuxedo, food: T("白身魚のムニエル", "Butter-fried white fish"), quirk: T("夕方にだけ正装する", "Dresses up only at dusk")),
        CatInfo(id: 6, name: T("ぷりん", "Custard"), coat: .cream, food: T("カスタードのはしっこ", "The edge of a custard tart"), quirk: T("塔のいちばん下にいがち", "Usually on the lowest floor")),
        CatInfo(id: 7, name: T("しまじろう", "Stripes"), coat: .tabby, food: T("あじの開き", "Grilled mackerel"), quirk: T("橋の真ん中で伸びる", "Stretches in the middle of bridges")),
        CatInfo(id: 8, name: T("あずき", "Bean"), coat: .smoke, food: T("あずき色のクッキー", "Red bean cookies"), quirk: T("屋根のかげで丸くなる", "Curls up in a roof's shade")),
        CatInfo(id: 9, name: T("ルナ", "Luna"), coat: .siamese, food: T("サーモンの切れはし", "Salmon scraps"), quirk: T("月が出ると窓辺に来る", "Comes to the window at moonrise")),
        CatInfo(id: 10, name: T("おもち", "Mochi"), coat: .white, food: T("やわらかいチーズ", "Soft cheese"), quirk: T("まるくなると石に見える", "Looks like a stone when curled")),
        CatInfo(id: 11, name: T("きなこ", "Toffee"), coat: .cream, food: T("きなこのビスケット", "Toffee biscuits"), quirk: T("日が傾くと色が変わって見える", "Changes color in the setting sun")),
        CatInfo(id: 12, name: T("ぽんず", "Ponzu"), coat: .ginger, food: T("みかんの皮（においだけ）", "Orange peel (just the smell)"), quirk: T("風見を回して遊ぶ", "Plays with the weathervane")),
        CatInfo(id: 13, name: T("くろまめ", "Pepper"), coat: .black, food: T("まぐろの赤身", "Tuna"), quirk: T("目だけ光らせて待つ", "Waits with only its eyes glowing")),
        CatInfo(id: 14, name: T("はいいろ", "Ash"), coat: .gray, food: T("ひよこ豆", "Chickpeas"), quirk: T("壁の色にあわせて座る", "Sits where the wall matches")),
        CatInfo(id: 15, name: T("ちゃとら", "Marmalade"), coat: .tabby, food: T("鶏の皮", "Crispy chicken skin"), quirk: T("階段を 1 段とばしでのぼる", "Climbs two steps at a time")),
        CatInfo(id: 16, name: T("ハチ", "Hachi"), coat: .tuxedo, food: T("ちくわ", "Fish cakes"), quirk: T("郵便受けの中に住んでいる", "Lives in a mailbox")),
        CatInfo(id: 17, name: T("こはく", "Amber"), coat: .ginger, food: T("はちみつのにおい", "The smell of honey"), quirk: T("夕日と同じ色で隠れる", "Hides in the sunset's color")),
        CatInfo(id: 18, name: T("ゆき", "Flurry"), coat: .white, food: T("冷たい水", "Cold water"), quirk: T("高いところほど機嫌がいい", "Happier the higher it is")),
        CatInfo(id: 19, name: T("もなか", "Wafer"), coat: .calico, food: T("最中の皮", "Wafer shells"), quirk: T("2 匹いるように見える", "Somehow looks like two cats")),
        CatInfo(id: 20, name: T("ソラ", "Sky"), coat: .smoke, food: T("雲みたいなメレンゲ", "Cloud-like meringue"), quirk: T("空の色に溶けこむ", "Melts into the sky")),
        CatInfo(id: 21, name: T("ごま", "Sesame"), coat: .tabby, food: T("ごまだんご", "Sesame balls"), quirk: T("すきまに挟まるのが好き", "Loves squeezing into gaps")),
        CatInfo(id: 22, name: T("ミルク", "Milky"), coat: .cream, food: T("あたためたミルク", "Warm milk"), quirk: T("見つかるとすぐ寝る", "Falls asleep as soon as found")),
        CatInfo(id: 23, name: T("つくし", "Sprout"), coat: .gray, food: T("ねこ草", "Cat grass"), quirk: T("植木鉢のふりをする", "Pretends to be a flowerpot")),
        // ここから Pro の塔だけに出る珍しい猫
        CatInfo(id: 24, name: T("灯台守のオリオン", "Orion the Keeper"), coat: .black, food: T("にしんの燻製", "Smoked herring"), quirk: T("灯りがつく時間を知っている", "Knows when the lamp lights up")),
        CatInfo(id: 25, name: T("時計屋のチクタク", "Ticktock"), coat: .tabby, food: T("歯車形のクッキー", "Gear-shaped cookies"), quirk: T("正時にだけ顔を出す", "Shows up only on the hour")),
        CatInfo(id: 26, name: T("温室のミント", "Mint"), coat: .white, food: T("キャットミント", "Catmint"), quirk: T("葉っぱの間で目を閉じる", "Closes its eyes among leaves")),
        CatInfo(id: 27, name: T("司書のページ", "Page the Librarian"), coat: .gray, food: T("古い紙のにおい", "The smell of old paper"), quirk: T("本棚の 3 段目で寝る", "Sleeps on the third shelf")),
        CatInfo(id: 28, name: T("風見のヴェーン", "Vane"), coat: .ginger, food: T("風に乗る羽根", "Feathers on the wind"), quirk: T("いつも風上を向く", "Always faces the wind")),
        CatInfo(id: 29, name: T("鐘つきのリン", "Ring"), coat: .siamese, food: T("鈴カステラ", "Bell-shaped sponge cakes"), quirk: T("鐘が鳴ると耳をふせる", "Flattens its ears at the bell")),
        CatInfo(id: 30, name: T("天文係のステラ", "Stella"), coat: .smoke, food: T("星形のチーズ", "Star-shaped cheese"), quirk: T("望遠鏡をのぞく", "Peeks through the telescope")),
        CatInfo(id: 31, name: T("パン屋のブリオッシュ", "Brioche"), coat: .cream, food: T("バターロール", "Butter rolls"), quirk: T("かまどの前で丸くなる", "Curls up by the oven")),
        CatInfo(id: 32, name: T("郵便係のスタンプ", "Stamp"), coat: .tuxedo, food: T("切手のふち", "Stamp edges"), quirk: T("手紙の上に座る", "Sits on letters")),
        CatInfo(id: 33, name: T("船乗りのアンカー", "Anchor"), coat: .tabby, food: T("塩焼きのさば", "Salted mackerel"), quirk: T("ロープの結び目にくわしい", "Knows every knot")),
        CatInfo(id: 34, name: T("帽子屋のフェルト", "Felt"), coat: .calico, food: T("リボンのはし", "Ribbon ends"), quirk: T("帽子の中に入る", "Climbs into hats")),
        CatInfo(id: 35, name: T("花屋のブーケ", "Bouquet"), coat: .ginger, food: T("花びらのにおい", "The smell of petals"), quirk: T("花かごに入って運ばれる", "Rides in flower baskets")),
        CatInfo(id: 36, name: T("雲の宿のフワリ", "Fluff"), coat: .white, food: T("綿あめ", "Cotton candy"), quirk: T("雲と見分けがつかない", "Can't be told apart from clouds")),
        CatInfo(id: 37, name: T("風車番のミル", "Mill"), coat: .gray, food: T("ひきたての麦", "Fresh-ground grain"), quirk: T("羽根といっしょに回る", "Spins with the blades")),
        CatInfo(id: 38, name: T("夜明けのアウローラ", "Aurora"), coat: .siamese, food: T("朝つゆ", "Morning dew"), quirk: T("塔をぜんぶ解いた人の前にだけ", "Appears only to those who solved every tower")),
        CatInfo(id: 39, name: T("迷子のポラリス", "Polaris"), coat: .smoke, food: T("道しるべのクッキー", "Signpost cookies"), quirk: T("いつも北の窓にいる", "Always at the north window")),
    ]

    // MARK: 塔（36）

    static func recipe(_ n: Int) -> TowerRecipe {
        // 番号が進むほど大きく・高く・橋が多くなる
        let palettes: [[Material]] = [
            [.terracotta, .sand, .mint], [.mint, .sand, .terracotta], [.sand, .terracotta, .plum],
            [.terracotta, .mint, .plum], [.plum, .sand, .mint], [.mint, .terracotta, .sand],
        ]
        let size = n <= 6 ? 5 : 7
        let maxH = n <= 3 ? 4 : (n <= 12 ? 5 : 6)
        return TowerRecipe(
            size: size, maxHeight: maxH,
            pillars: n <= 6 ? 4...6 : 7...11,
            bridges: n <= 3 ? 1...1 : (n <= 12 ? 1...2 : 2...3),
            materials: palettes[n % palettes.count],
            roofChance: 0.35
        )
    }

    static let towerNames: [T] = [
        T("はじまりの塔", "First Tower"), T("パン屋の塔", "Bakery Tower"), T("郵便塔", "Post Tower"), T("風見の家", "Weathervane House"),
        T("給水塔", "Water Tower"), T("花屋の塔", "Flower Tower"), T("糸巻き塔", "Spool Tower"), T("帽子屋の塔", "Hatter's Tower"),
        T("灯台", "Lighthouse"), T("時計台", "Clock Tower"), T("温室", "Greenhouse"), T("図書塔", "Library Spire"),
        T("鐘楼", "Bell Tower"), T("天文台", "Observatory"), T("風車", "Windmill"), T("船着き塔", "Harbor Tower"),
        T("雲の宿", "Cloud Inn"), T("蜂の巣塔", "Hive Tower"), T("星見台", "Stargazer Deck"), T("古い水門", "Old Floodgate"),
        T("階段の家", "House of Stairs"), T("ふたご塔", "Twin Towers"), T("鳥かご塔", "Birdcage Tower"), T("ランプ屋", "Lamp Shop"),
        T("音楽塔", "Music Tower"), T("砂時計塔", "Hourglass Tower"), T("凧揚げ台", "Kite Deck"), T("月の階段", "Moon Stairs"),
        T("影の回廊", "Shadow Arcade"), T("逆さ塔", "Upside Tower"), T("迷い橋", "Lost Bridges"), T("空中庭園", "Sky Garden"),
        T("三つ角の塔", "Three-Corner Tower"), T("夕暮れ駅", "Dusk Station"), T("夜明けの塔", "Dawn Tower"), T("ねこの城", "Cat Castle"),
    ]

    static var towerCount: Int { towerNames.count }

    static func info(_ n: Int) -> TowerInfo {
        TowerInfo(number: n, name: towerNames[max(0, min(towerNames.count - 1, n - 1))], recipe: recipe(n))
    }

    static func isFree(_ id: TowerID, today: String) -> Bool {
        switch id {
        case .numbered(let n): n <= freeTowers || n == trialTower
        case .daily(let d): d == today
        }
    }

    // MARK: 塔を作る

    static func seed(_ id: TowerID) -> UInt64 {
        switch id {
        case .numbered(let n): return UInt64(n) &* 7919 &+ 104_729
        case .daily(let d):
            // 文字列のハッシュは起動ごとに変わるので、自前で数にする
            var h: UInt64 = 1_469_598_103_934_665_603
            for b in d.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
            return h
        }
    }

    /// 猫を選ぶ。無料の塔はふつうの猫、Pro の塔には珍しい猫が 2 匹まじる
    static func catIDs(_ id: TowerID) -> [Int] {
        var rng = SeededRNG(seed: seed(id) ^ 0xCA7)
        var common = Array(0..<commonCats)
        common.shuffle(using: &rng)
        var picked = Array(common.prefix(5))
        if case .numbered(let n) = id, n > freeTowers {
            var rare = Array(commonCats..<cats.count)
            rare.shuffle(using: &rng)
            picked[1] = rare[0]
            picked[4] = rare[1]
        }
        return picked
    }

    static func recipe(for id: TowerID) -> TowerRecipe {
        switch id {
        case .numbered(let n): return recipe(n)
        case .daily(let d):
            // 毎日の塔は中くらい（曜日で少し変わる）
            let r = Int(seed(.daily(d)) % 3)
            return TowerRecipe(size: r == 0 ? 5 : 7, maxHeight: 5, pillars: r == 0 ? 5...7 : 7...10, bridges: 1...2,
                               materials: recipe(Int(seed(.daily(d)) % 6) + 1).materials, roofChance: 0.35)
        }
    }

    static func tower(_ id: TowerID) -> Tower {
        TowerGenerator.make(seed: seed(id), recipe: recipe(for: id), catIDs: catIDs(id))
    }

    static func name(_ id: TowerID) -> String {
        switch id {
        case .numbered(let n): return info(n).name.text
        case .daily(let d):
            let parts = d.split(separator: "-")
            let md = parts.count == 3 ? "\(Int(parts[1]) ?? 0)/\(Int(parts[2]) ?? 0)" : d
            return trf("今日の塔 %@", "Today's Tower %@", md)
        }
    }
}

enum Samples {
    /// 作り直しても条件に合わないときの、小さな見本の塔（テストで来ないことを確かめる）
    static func fallback(catIDs: [Int]) -> Tower {
        var solids = Set<Cell>()
        for x in 0..<5 { solids.insert(Cell(x: x, y: 2, z: 0)) }
        for z in 0..<3 { solids.insert(Cell(x: 2, y: 2, z: z)) }
        let ids = catIDs.count >= 5 ? catIDs : [0, 1, 2, 3, 4]
        let f = Face(cell: Cell(x: 2, y: 2, z: 2), dir: .south)
        return Tower(size: 5, solids: solids, roofs: [], ladders: [Ladder(cell: Cell(x: 2, y: 2, z: 1), dir: .east)], materials: [:], windows: [f],
                     cats: [CatSpot(id: 0, kind: .window, catID: ids[0], face: f)], start: Top(x: 0, y: 2, h: 1))
    }
}
