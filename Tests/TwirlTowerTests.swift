import Foundation
import Testing
@testable import TwirlTower

/// 小さな手作りの塔：向き 0 では、低い床 A(0,2,1) と高い床 B(2,3,2) が画面で隣り合って見える（錯視の道）
private func illusionTower() -> Tower {
    var solids = Set<Cell>()
    solids.insert(Cell(x: 0, y: 2, z: 0))  // A
    solids.insert(Cell(x: 1, y: 2, z: 0))  // A のとなり
    for z in 0..<2 { solids.insert(Cell(x: 2, y: 4, z: z)) }  // B の柱（中心から見て奥）
    let a = Top(x: 1, y: 2, h: 1)
    return Tower(size: 5, solids: solids, roofs: [], ladders: [], materials: [:], windows: [], cats: [], start: a)
}

struct GeometryTests {
    @Test func rotatingFourTimesComesBack() {
        for (a, b) in [(1, 0), (2, -1), (0, 0)] {
            let (p, q) = Tower.rotate(a, b, view: 4)
            #expect(p == a && q == b)
            let (p1, q1) = Tower.rotate(a, b, view: 1)
            #expect(p1 == -b && q1 == a)
        }
    }

    @Test func pointsAlongTheCameraOverlapOnScreen() {
        let t = illusionTower()
        // (1,1,1) だけずれた点は、どの向きでも画面で重なる
        for v in 0..<4 {
            let base = Top(x: 2, y: 2, h: 1)
            // 回した座標で (+1,+1,+1)：世界の座標に戻してから比べる
            let (dx, dy) = Tower.rotate(1, 1, view: (4 - v) % 4)
            let moved = Top(x: 2 + dx, y: 2 + dy, h: 2)
            #expect(t.screenKey(base, view: v) == t.screenKey(moved, view: v))
        }
    }

    @Test func sameHeightNeighboursAreAlwaysConnected() {
        let t = illusionTower()
        let a = Top(x: 0, y: 2, h: 1), b = Top(x: 1, y: 2, h: 1)
        #expect(t.trueNeighbors(a).contains(b))
        #expect(!t.isIllusion(a, b))
    }

    @Test func screenNeighboursDependOnTheView() {
        // 画面で隣り合う床の組は、向きで変わる（錯視の道）。どの塔でも、どこかの向きで錯視の道がある
        let tower = Catalog.tower(.numbered(1))
        var illusions = 0
        for v in 0..<4 {
            let vis = tower.visibleTops(view: v)
            for t in vis {
                illusions += tower.screenNeighbors(t, view: v, visible: vis).filter { tower.isIllusion(t, $0) }.count
            }
        }
        #expect(illusions > 0)
    }

    @Test func aBlockInFrontHidesTheFaceBehind() {
        var solids: Set<Cell> = [Cell(x: 2, y: 2, z: 0), Cell(x: 3, y: 2, z: 0)]
        let t = Tower(size: 5, solids: solids, roofs: [], ladders: [], materials: [:], windows: [], cats: [], start: Top(x: 2, y: 2, h: 1))
        // 東どうしでふさがった面は開いていない
        #expect(!t.faceIsOpen(Face(cell: Cell(x: 2, y: 2, z: 0), dir: .east)))
        solids.remove(Cell(x: 3, y: 2, z: 0))
        let t2 = Tower(size: 5, solids: solids, roofs: [], ladders: [], materials: [:], windows: [], cats: [], start: Top(x: 2, y: 2, h: 1))
        let east = Face(cell: Cell(x: 2, y: 2, z: 0), dir: .east)
        // 1 つだけのブロックの面は、こちらを向く 2 つの向きでだけ見える
        #expect(t2.faceViews(east).count == 2)
    }
}

struct TowerContentTests {
    @Test(arguments: 1...36)
    func everyNumberedTowerHasFiveFindableCats(n: Int) {
        let t = Catalog.tower(.numbered(n))
        #expect(t.cats.count == 5)
        #expect(t.allCatsFindable)
        // どの猫も、少なくとも 1 つの向きで見つけられる
        for c in t.cats { #expect(!t.views(of: c).isEmpty) }
    }

    @Test func dailyTowersForTwoMonthsAreFindable() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 21))!
        for i in 0..<60 {
            let key = Days.offset(start, days: i, calendar: cal)
            let t = Catalog.tower(.daily(key))
            #expect(t.cats.count == 5, "\(key)")
            #expect(t.allCatsFindable, "\(key)")
        }
    }

    @Test func roofCatsNeedTheIllusion() {
        // 屋上の猫は、本当の道だけでは行けない（錯視の道を使う）
        for n in [1, 9, 20] {
            let t = Catalog.tower(.numbered(n))
            let w = Walker(tower: t)
            let truly = w.trulyReachable(from: t.start)
            for c in t.cats where c.kind == .roof { #expect(!truly.contains(c.top!)) }
        }
    }

    @Test func sameSeedSameTower() {
        let a = Catalog.tower(.daily("2026-11-21")), b = Catalog.tower(.daily("2026-11-21"))
        #expect(a.solids == b.solids)
        #expect(a.cats == b.cats)
        #expect(Catalog.tower(.daily("2026-11-22")).solids != a.solids)
    }

    @Test func freeTowersOnlyHaveCommonCats() {
        for n in 1...Catalog.freeTowers {
            #expect(Catalog.catIDs(.numbered(n)).allSatisfy { $0 < Catalog.commonCats })
        }
        #expect(Catalog.catIDs(.numbered(20)).contains { $0 >= Catalog.commonCats })
    }

    @Test func catBookHasFortyCatsInTwoLanguages() {
        #expect(Catalog.cats.count == 40)
        #expect(Set(Catalog.cats.map(\.id)).count == 40)
        for c in Catalog.cats {
            #expect(!c.name.ja.isEmpty && !c.name.en.isEmpty && !c.food.en.isEmpty && !c.quirk.en.isEmpty)
        }
        #expect(Catalog.towerNames.count == 36)
    }

    @Test func trialTowerIsFree() {
        #expect(Catalog.isFree(.numbered(1), today: "2026-11-21"))
        #expect(Catalog.isFree(.numbered(Catalog.trialTower), today: "2026-11-21"))
        #expect(!Catalog.isFree(.numbered(10), today: "2026-11-21"))
        #expect(Catalog.isFree(.daily("2026-11-21"), today: "2026-11-21"))
        #expect(!Catalog.isFree(.daily("2026-11-20"), today: "2026-11-21"))
    }
}

struct HuntTests {
    /// 解き方を自分で探して、全部の猫を見つけられるか（向きを変え、歩き、たたく）
    @Test(arguments: [TowerID.numbered(1), .numbered(5), .numbered(14), .daily("2026-11-21")])
    func aSolverCanFindEveryCat(id: TowerID) {
        var hunt = Hunt(tower: Catalog.tower(id))
        for c in hunt.tower.cats {
            switch c.kind {
            case .window:
                let v = hunt.tower.views(of: c)[0]
                hunt.turn(v - hunt.view)
                #expect(hunt.tapCat(c.id) == .found(c.id))
            case .shadow:
                for v in c.marks {
                    hunt.turn(v - hunt.view)
                    _ = hunt.tapCat(c.id)
                }
                #expect(hunt.progress.found.contains(c.id))
            case .roof:
                guard let route = hunt.walker.route(from: hunt.at, view: hunt.view, to: c.top!) else {
                    Issue.record("屋上の猫に行けない")
                    continue
                }
                for s in route.dropFirst() {
                    if s.view != hunt.view { hunt.turn(s.view - hunt.view) } else { _ = hunt.step(to: s.top) }
                }
                #expect(hunt.progress.found.contains(c.id))
            }
        }
        #expect(hunt.isComplete)
        #expect(hunt.progress.done)
        #expect(hunt.progress.lamps == 3)
    }

    @Test func windowCatIsOnlyFoundFromTheRightSide() {
        var hunt = Hunt(tower: Catalog.tower(.numbered(3)))
        let c = hunt.tower.cats.first { $0.kind == .window }!
        let views = hunt.tower.views(of: c)
        let wrong = (0..<4).first { !views.contains($0) }!
        hunt.turn(wrong - hunt.view)
        #expect(hunt.tapCat(c.id) == .nothing)
        hunt.turn(views[0] - hunt.view)
        #expect(hunt.tapCat(c.id) == .found(c.id))
        #expect(hunt.tapCat(c.id) == .already)
    }

    @Test func shadowCatNeedsTwoViews() {
        var hunt = Hunt(tower: Catalog.tower(.numbered(2)))
        let c = hunt.tower.cats.first { $0.kind == .shadow }!
        hunt.turn(c.marks[0] - hunt.view)
        #expect(hunt.tapCat(c.id) == .mark(c.id, complete: false))
        hunt.turn(c.marks[1] - hunt.view)
        #expect(hunt.tapCat(c.id) == .mark(c.id, complete: true))
        #expect(hunt.progress.found.contains(c.id))
    }

    @Test func roofCatIsFarUntilYouWalkThere() {
        var hunt = Hunt(tower: Catalog.tower(.numbered(4)))
        let c = hunt.tower.cats.first { $0.kind == .roof }!
        #expect(hunt.tapCat(c.id) == .farAway(c.id))
    }

    @Test func hintsGoThroughThreeLevelsAndCostLamps() {
        var hunt = Hunt(tower: Catalog.tower(.numbered(6)))
        let h1 = hunt.nextHint()
        #expect(h1?.level == 1)
        #expect(hunt.nextHint()?.level == 2)
        #expect(hunt.nextHint()?.level == 3)
        #expect(hunt.nextHint()?.level == 3)  // 3 段目より先には進まない（数えない）
        #expect(hunt.progress.hints == 3)
        #expect(Hunt.lamps(hints: 0) == 3)
        #expect(Hunt.lamps(hints: 3) == 2)
        #expect(Hunt.lamps(hints: 4) == 1)
    }

    @Test func hintTurnsPointTheShortWay() {
        #expect(Hunt.turns(from: 0, to: 1) == 1)
        #expect(Hunt.turns(from: 0, to: 3) == -1)
        #expect(Hunt.turns(from: 1, to: 3) == 2)
        #expect(Hunt.turns(from: 2, to: 2) == 0)
    }

    @Test func savedProgressResumes() throws {
        var hunt = Hunt(tower: Catalog.tower(.numbered(1)))
        hunt.turn(1)
        let c = hunt.tower.cats.first { $0.kind == .window }!
        hunt.turn(hunt.tower.views(of: c)[0] - hunt.view)
        _ = hunt.tapCat(c.id)
        let data = try JSONEncoder().encode(hunt.progress)
        let back = try JSONDecoder().decode(TowerProgress.self, from: data)
        let resumed = Hunt(tower: Catalog.tower(.numbered(1)), progress: back)
        #expect(resumed.progress.found == hunt.progress.found)
        #expect(resumed.view == hunt.view)
    }
}

struct SaveTests {
    @Test func streakCountsConsecutiveDailyTowers() {
        var s = SaveData()
        s.complete(.daily("2026-11-20"), today: "2026-11-20", yesterday: "2026-11-19")
        #expect(s.streak == 1)
        s.complete(.daily("2026-11-21"), today: "2026-11-21", yesterday: "2026-11-20")
        #expect(s.streak == 2)
        s.complete(.daily("2026-11-21"), today: "2026-11-21", yesterday: "2026-11-20")
        #expect(s.streak == 2)  // 同じ日は 1 回だけ
        s.complete(.daily("2026-11-24"), today: "2026-11-24", yesterday: "2026-11-23")
        #expect(s.streak == 1)
        #expect(s.bestStreak == 2)
        #expect(s.currentStreak(today: "2026-11-26", yesterday: "2026-11-25") == 0)
    }

    @Test func numberedTowersDoNotCountForTheStreak() {
        var s = SaveData()
        s.complete(.numbered(3), today: "2026-11-21", yesterday: "2026-11-20")
        #expect(s.streak == 0)
    }

    @Test func catBookCountsFinds() throws {
        var s = SaveData()
        s.record(cat: 3)
        s.record(cat: 3)
        s.record(cat: 30)
        #expect(s.catsFound[3] == 2)
        #expect(s.catsKnown == 2)
        let back = try JSONDecoder().decode(SaveData.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
