import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/garden.test.ts (and the garden-time test in
/// web/tests/profile-and-round.test.ts): the same farm rules in both apps.
@MainActor
final class GardenTests: XCTestCase {
    private let columns = Farm.columns

    private func day(_ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 10))!
    }

    /// A farm far enough along that every item is unlocked.
    private func rich(_ stars: Int = 500) -> Farm {
        Farm(profileID: "lena", walletStars: stars, xp: 5000)
    }

    private func place(_ farm: Farm, _ cell: Int, _ id: String, _ d: Int = 1) -> Farm {
        var rng = SeededGenerator(seed: UInt64(cell))
        return farm.placing(id, at: cell, now: day(d), using: &rng)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Buildings

    func testBuildingsTakeDaysAndBigOnesCoverSeveralCells() {
        let p = place(rich(), 0, "barn")
        XCTAssertEqual(p.walletStars, 460)
        XCTAssertEqual(Farm.picture(of: p.garden[0]!, now: day(1)), "🚧")
        XCTAssertEqual(Farm.daysUntilNextStage(p.garden[0]!, now: day(1)), 2)
        XCTAssertEqual(Farm.picture(of: p.garden[0]!, now: day(3)), "art:barn")
        let covered = Farm.occupancy(p.garden)
        XCTAssertEqual([0, 1, columns, columns + 1].map { covered[$0] }, [0, 0, 0, 0])
        XCTAssertNil(covered[2])
        // Nothing else fits on top of it.
        XCTAssertEqual(p.placementProblem(at: columns + 1, itemID: "stone", now: day(1)), .space)
    }

    func testBigItemsShiftLeftOrUpAtTheEdge() {
        let p = place(rich(), columns - 1, "pond")
        XCTAssertEqual(p.garden[columns - 2]?.itemId, "pond")
        let bottomRight = Farm.startSize - 1
        let q = place(rich(), bottomRight, "barn")
        XCTAssertEqual(q.garden[bottomRight - columns - 1]?.itemId, "barn")
    }

    // MARK: Animals

    func testFarmAnimalsNeedAFinishedHomeWithRoom() {
        var p = rich()
        XCTAssertEqual(p.placementProblem(at: 5, itemID: "cow", now: day(1)), .home)
        p = place(p, 0, "barn")
        XCTAssertEqual(p.placementProblem(at: 5, itemID: "cow", now: day(2)), .home, "still being built")
        for (i, id) in ["cow", "pig", "sheep", "horse"].enumerated() { p = place(p, 2 + i, id, 3) }
        let space = p.homeSpace(.farm, now: day(3))
        XCTAssertEqual(space.capacity, 4)
        XCTAssertEqual(space.used, 4)
        XCTAssertEqual(p.placementProblem(at: 12, itemID: "goat", now: day(3)), .full)
        // A full home can't be cleared away from under its animals.
        XCTAssertFalse(p.canClear(0, now: day(3)))
        XCTAssertEqual(p.clearing(0, now: day(3)), p)
        XCTAssertFalse(p.clearing(2, now: day(3)).canClear(0, now: day(3)))
    }

    func testSmallAnimalsLiveAnywhereAndAHouseIsHomeForCats() {
        var p = place(rich(), 0, "rabbit")
        XCTAssertEqual(p.garden[0]?.itemId, "rabbit")
        XCTAssertEqual(p.placementProblem(at: 1, itemID: "cat", now: day(1)), .home)
        p = place(p, 1, "house")
        XCTAssertNil(p.placementProblem(at: 2, itemID: "cat", now: day(1)))
    }

    func testChicksGrowIntoHensThatLayOneEggADay() {
        var p = place(place(rich(), 0, "coop"), 1, "chick", 2)
        XCTAssertEqual(Farm.picture(of: p.garden[1]!, now: day(2)), "🐣")
        XCTAssertEqual(Farm.picture(of: p.garden[1]!, now: day(4)), "🐥")
        XCTAssertNil(Farm.readyProduce(p.garden[1]!, now: day(4)))
        XCTAssertEqual(Farm.picture(of: p.garden[1]!, now: day(6)), "🐔")
        XCTAssertEqual(Farm.readyProduce(p.garden[1]!, now: day(6)), .egg)
        p = p.collecting(1, now: day(6))
        XCTAssertEqual(p.goods(.egg), 1)
        XCTAssertNil(Farm.readyProduce(p.garden[1]!, now: day(6)))
        XCTAssertEqual(p.collecting(1, now: day(6)), p)
        XCTAssertEqual(Farm.readyProduce(p.garden[1]!, now: day(7)), .egg)
    }

    func testCowsGiveMilkFromTheDayAfterTheyArrive() {
        var p = place(place(rich(), 0, "barn"), 2, "cow", 3)
        XCTAssertNil(Farm.readyProduce(p.garden[2]!, now: day(3)))
        p = p.collecting(2, now: day(4))
        XCTAssertEqual(p.goods(.milk), 1)
    }

    func testSellsGoodsInFivesForSpendableStarsOnly() {
        var p = rich(10)
        p.goods[.egg] = 7
        p.goods[.milk] = 4
        let sold = p.selling()
        XCTAssertEqual(sold.walletStars, 12)
        XCTAssertEqual(sold.goods(.egg), 0)
        XCTAssertEqual(sold.goods(.milk), 1)
        XCTAssertEqual(sold.selling(), sold)
    }

    func testSellingNeverTouchesLifetimeStars() throws {
        let context = try makeContext()
        let child = ChildProfile(name: "Lena", age: 6)
        context.insert(child)
        child.totalStars = 50
        child.walletStars = 10
        var farm = child.farm
        farm.goods[.egg] = 5
        child.setFarm(farm.selling())
        XCTAssertEqual(child.walletStars, 11)
        XCTAssertEqual(child.totalStars, 50)
    }

    // MARK: Land

    func testLandAddsFourRowsAtATimeThreeTimes() {
        var p = rich(200)
        XCTAssertEqual(p.rows, 8)
        for price in [25, 40, 60] {
            XCTAssertEqual(p.nextLandPrice, price)
            let before = p.walletStars
            p = p.buyingLand()
            XCTAssertEqual(p.walletStars, before - price)
        }
        XCTAssertEqual(p.rows, 20)
        XCTAssertNil(p.nextLandPrice)
        XCTAssertEqual(p.buyingLand(), p)
    }

    func testOldSixColumnGardensMoveIntoTheWideFarm() throws {
        let context = try makeContext()
        let short = ChildProfile(name: "X", age: 6)
        context.insert(short)
        short.setWebField("garden", [GardenPlot(itemId: "flower", plantedDay: "2026-10-01")] as [GardenPlot?])
        XCTAssertEqual(short.farm.garden.count, Farm.startSize)
        XCTAssertEqual(short.farm.goodsCount, 0)

        // 6 columns × 6 rows = one land purchase; a barn at row 1, column 4.
        var legacy = [GardenPlot?](repeating: nil, count: 36)
        legacy[6 + 4] = GardenPlot(itemId: "barn", plantedDay: "2026-10-01")
        legacy[35] = GardenPlot(itemId: "stone", plantedDay: "2026-10-01")
        let child = ChildProfile(name: "Y", age: 6)
        context.insert(child)
        child.setWebField("garden", legacy)
        let moved = child.farm
        XCTAssertEqual(moved.rows, 12)
        XCTAssertEqual(moved.garden[columns + 4]?.itemId, "barn")
        XCTAssertEqual(moved.garden[5 * columns + 5]?.itemId, "stone")
        XCTAssertEqual(moved.nextLandPrice, 40)
        // Saved again, it is not moved a second time.
        child.setFarm(moved)
        XCTAssertEqual(child.webField("gardenColumns", as: Int.self), 16)
        XCTAssertEqual(child.farm.garden, moved.garden)
    }

    func testEveryItemHasMatchingStagesPricesAndHomes() {
        for item in GardenItem.all {
            XCTAssertEqual(item.stages.count, item.days.count, item.id)
            XCTAssertGreaterThanOrEqual(item.price, item.connects ? 0 : 1, item.id)
            XCTAssertEqual(item.price == 0, item.category == .paths, item.id)
            if let needs = item.needs {
                XCTAssertTrue(GardenItem.all.contains { $0.houses?.group == needs }, item.id)
            }
        }
    }

    // MARK: Roads

    func testRoadsPathsAndFencesAreFreeAndJoinUp() {
        var p = rich(0)
        for cell in [0, 1, 2, 2 + columns] { p = place(p, cell, "road") }
        p = place(p, 3, "fence")
        XCTAssertEqual(p.walletStars, 0)
        XCTAssertEqual(Farm.connections(p.garden, cell: 0), Farm.Links(n: false, e: true, s: false, w: false))
        XCTAssertEqual(Farm.connections(p.garden, cell: 2), Farm.Links(n: false, e: false, s: true, w: true))
        // A road doesn't join a fence; the right edge doesn't wrap to the next row.
        XCTAssertEqual(Farm.connections(p.garden, cell: 3), Farm.Links())
        let edge = place(place(rich(0), columns - 1, "path"), columns, "path")
        XCTAssertFalse(Farm.connections(edge.garden, cell: columns - 1).e)
    }

    // MARK: Levels

    private func fresh() -> Farm { Farm(profileID: "emil", walletStars: 300) }

    func testLevelsGrowWithXpAndUnlockItemsStepByStep() {
        XCTAssertEqual(FarmLevel(xp: 0), FarmLevel(level: 1, xpInLevel: 0, xpForNext: 10))
        XCTAssertEqual(FarmLevel(xp: 35).level, 3)
        XCTAssertEqual(FarmLevel(xp: 460).level, 10)
        XCTAssertEqual(FarmLevel(xp: 560).level, 11)
        XCTAssertTrue(GardenItem.unlocked(at: 4).map(\.id).contains("barn"))
        XCTAssertEqual(fresh().placementProblem(at: 0, itemID: "barn", now: day(1)), .level)
        XCTAssertNil(fresh().placementProblem(at: 0, itemID: "wheat", now: day(1)))
    }

    func testOneXpPerStarSpentAndSomeForCollecting() {
        var p = place(fresh(), 0, "tree")
        XCTAssertEqual(p.xp, 12)
        XCTAssertEqual(p.level.level, 2)
        p = place(p, 1, "wheat")
        p = p.collecting(1, now: day(2))
        XCTAssertEqual(p.xp, 12 + 3 + 3)
    }

    func testFarmsBuiltBeforeLevelsAreCredited() throws {
        var g = Farm.emptyGarden()
        g[0] = GardenPlot(itemId: "barn", plantedDay: "2026-10-01")
        g[5] = GardenPlot(itemId: "cow", plantedDay: "2026-10-01")
        XCTAssertEqual(Farm.startingXp(g), 65)

        let context = try makeContext()
        let child = ChildProfile(name: "Z", age: 6)
        context.insert(child)
        child.setWebField("garden", g)
        child.setWebField("gardenColumns", 16)
        XCTAssertEqual(child.farm.xp, 65)
        XCTAssertGreaterThanOrEqual(child.farm.level.level, 4, "keeps barn-level items")
    }

    // MARK: Harvest

    func testCollectsGrownCropsWhichThenGrowAgain() {
        var p = place(rich(), 0, "wheat")
        XCTAssertNil(Farm.readyProduce(p.garden[0]!, now: day(1)))
        XCTAssertEqual(Farm.readyProduce(p.garden[0]!, now: day(2)), .wheat)
        p = p.collecting(0, now: day(2))
        XCTAssertEqual(p.goods(.wheat), 1)
        XCTAssertEqual(Farm.picture(of: p.garden[0]!, now: day(2)), "🌱")
        XCTAssertEqual(Farm.readyProduce(p.garden[0]!, now: day(3)), .wheat)
    }

    func testListsEverythingReadyToCollect() {
        var p = place(place(rich(), 0, "wheat"), 1, "beehive")
        p = place(p, 2, "appletree")
        XCTAssertEqual(Farm.readyCells(p.garden, now: day(1)), [])
        XCTAssertEqual(Farm.readyCells(p.garden, now: day(2)), [0, 1])
        XCTAssertEqual(Farm.readyCells(p.garden, now: day(5)), [0, 1, 2])
    }

    // MARK: Orders

    func testOrdersAskForGoodsTheFarmCanMakeAndPayBetter() {
        XCTAssertEqual(rich().withTodaysOrders(now: day(1)).orders?.orders, [])
        var p = place(place(rich(), 0, "coop"), 1, "chick", 2).withTodaysOrders(now: day(2))
        let orders = p.orders!.orders
        XCTAssertEqual(orders.count, 3)
        for o in orders {
            XCTAssertEqual(Array(o.wants.keys), ["egg"])
            XCTAssertGreaterThanOrEqual(o.stars, 1 + o.wants(.egg) / 3)
        }
        // The same orders all day long.
        XCTAssertEqual(p.withTodaysOrders(now: day(2)), p)
        XCTAssertNotEqual(p.withTodaysOrders(now: day(3)).orders?.day, p.orders?.day)

        let order = orders[0]
        XCTAssertEqual(p.fulfilling(order.id), p, "not enough eggs yet")
        p.goods[.egg] = 10
        let done = p.fulfilling(order.id)
        XCTAssertEqual(done.walletStars, p.walletStars + order.stars)
        XCTAssertEqual(done.goods(.egg), 10 - order.wants(.egg))
        XCTAssertEqual(done.orders?.orders[0].done, true)
        XCTAssertEqual(done.fulfilling(order.id), done)
    }

    /// Made with the web app's withTodaysOrders for the same child, farm and day.
    func testOrdersAreTheSameAsInTheWebApp() {
        var g = Farm.emptyGarden()
        g[0] = GardenPlot(itemId: "coop", plantedDay: "2026-10-10")
        g[1] = GardenPlot(itemId: "chick", plantedDay: "2026-10-10")
        g[2] = GardenPlot(itemId: "barn", plantedDay: "2026-10-10")
        g[4] = GardenPlot(itemId: "cow", plantedDay: "2026-10-12")
        g[20] = GardenPlot(itemId: "wheat", plantedDay: "2026-10-12")
        let id = "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69"
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 10))!

        // The barn makes cheese from milk, so cheese can be ordered too.
        let big = Farm(profileID: id, garden: g, xp: 140).withTodaysOrders(now: now).orders
        XCTAssertEqual(big, FarmOrders(day: "2026-10-18", orders: [
            FarmOrder(id: "2026-10-18-0", wants: ["milk": 4, "egg": 4], stars: 3, xp: 24),
            FarmOrder(id: "2026-10-18-1", wants: ["wheat": 2, "egg": 2], stars: 2, xp: 12),
            FarmOrder(id: "2026-10-18-2", wants: ["wheat": 3], stars: 2, xp: 9),
        ]))
        let small = Farm(profileID: id, garden: g, xp: 20).withTodaysOrders(now: now).orders
        XCTAssertEqual(small, FarmOrders(day: "2026-10-18", orders: [
            FarmOrder(id: "2026-10-18-0", wants: ["milk": 3, "egg": 3], stars: 3, xp: 18),
            FarmOrder(id: "2026-10-18-1", wants: ["wheat": 2, "egg": 2], stars: 2, xp: 12),
            FarmOrder(id: "2026-10-18-2", wants: ["wheat": 2], stars: 1, xp: 6),
        ]))
        // A mailbox brings a fourth order, a horse one more star on each.
        var more = g
        more[6] = GardenPlot(itemId: "mailbox", plantedDay: "2026-10-12")
        more[40] = GardenPlot(itemId: "horse", plantedDay: "2026-10-12")
        let bonus = Farm(profileID: id, garden: more, xp: 140).withTodaysOrders(now: now).orders
        XCTAssertEqual(bonus, FarmOrders(day: "2026-10-18", orders: [
            FarmOrder(id: "2026-10-18-0", wants: ["milk": 4, "egg": 4], stars: 4, xp: 24),
            FarmOrder(id: "2026-10-18-1", wants: ["wheat": 2, "egg": 2], stars: 3, xp: 12),
            FarmOrder(id: "2026-10-18-2", wants: ["wheat": 3], stars: 3, xp: 9),
            FarmOrder(id: "2026-10-18-3", wants: ["wheat": 4], stars: 3, xp: 12),
        ]))
    }

    // MARK: Everything does something

    func testEveryPlantAnimalAndBuildingDoesSomething() {
        let useless = GardenItem.all
            .filter { [.plants, .animals, .buildings].contains($0.category) }
            .filter { $0.produce == nil && $0.harvest == nil && $0.boosts == nil && $0.houses == nil && $0.recipe == nil && $0.orders == nil }
        XCTAssertEqual(useless.map(\.id), [])
    }

    func testGoatsGiveMilkPigsBaconSheepWoolPondsFish() {
        var p = place(place(rich(), 0, "barn"), 2, "goat", 3)
        p = place(p, 3, "pig", 3)
        p = place(p, 4, "sheep", 3)
        p = place(p, 6, "pond", 1)
        for cell in [2, 3, 4, 6] { p = p.collecting(cell, now: day(5)) }
        XCTAssertEqual([p.goods(.milk), p.goods(.bacon), p.goods(.wool), p.goods(.fish)], [1, 1, 1, 1])
    }

    func testHelpersAddOneMoreOncePerKind() {
        var p = place(rich(), 0, "wheat")
        p = place(p, 1, "vegetable")
        p = place(p, 2, "ladybug")
        p = place(p, 3, "ladybug")
        p = place(p, 4, "tractor")
        p = p.collecting(0, now: day(5)).collecting(1, now: day(5))
        XCTAssertEqual(p.goods(.wheat), 2)
        XCTAssertEqual(p.goods(.veg), 3)
    }

    func testMillBarnAndFarmhouseMakeBreadCheeseAndPie() {
        var p = place(place(place(rich(), 0, "windmill"), 2, "barn"), 4, "farmhouse")
        p.goods[.wheat] = 3
        p.goods[.milk] = 2
        p.goods[.apple] = 1
        p.goods[.egg] = 1
        XCTAssertFalse(p.canMake(at: 0, now: day(1))) // still being built
        XCTAssertEqual(p.making(at: 0, now: day(1)), p)
        p = p.making(at: columns, now: day(10)) // any square of the mill
        XCTAssertEqual(p.goods(.wheat), 1)
        XCTAssertEqual(p.goods(.bread), 1)
        XCTAssertFalse(p.canMake(at: 0, now: day(10))) // one wheat left
        p = p.making(at: 2, now: day(10)).making(at: 4, now: day(10))
        XCTAssertEqual([p.goods(.wheat), p.goods(.milk), p.goods(.apple), p.goods(.egg)], [0, 0, 0, 0])
        XCTAssertEqual([p.goods(.cheese), p.goods(.pie)], [1, 1])
    }

    func testFarmShopCountsMadeGoodsMoreAndSellsWholeStarsOnly() {
        var p = rich(0)
        p.goods[.bread] = 1
        p.goods[.pie] = 1
        p.goods[.egg] = 3
        XCTAssertEqual(p.sellableStars, 2) // 3 + 5 + 3 = 11
        let sold = p.selling()
        XCTAssertEqual(sold.walletStars, 2)
        XCTAssertEqual([sold.goods(.egg), sold.goods(.bread), sold.goods(.pie)], [1, 0, 0])
        // Three breads are worth 9, but no choice of them makes exactly 5.
        var breads = rich(0)
        breads.goods[.bread] = 3
        XCTAssertEqual(breads.sellableStars, 0)
        XCTAssertEqual(breads.selling(), breads)
        breads.goods[.egg] = 2
        let mixed = breads.selling()
        XCTAssertEqual(mixed.walletStars, 2)
        XCTAssertEqual([mixed.goods(.bread), mixed.goods(.egg)], [0, 1])
    }

    func testOrdersIncludeWhatTheMillMakes() {
        var p = place(place(rich(), 0, "coop"), 1, "chick", 2)
        p = place(place(p, 20, "windmill"), 3, "wheat")
        XCTAssertTrue(Farm.producibleGoods(p.garden).contains(.bread))
        XCTAssertFalse(Farm.producibleGoods(p.garden).contains(.cheese)) // no milk on this farm
    }

    // MARK: Moving

    func testMovesAnItemBigOnesTooKeepingItsAge() {
        var p = place(rich(), 0, "barn")
        p = p.moving(from: columns + 1, to: 5)
        XCTAssertNil(p.garden[0])
        XCTAssertEqual(p.garden[5]?.itemId, "barn")
        XCTAssertEqual(p.garden[5]?.plantedDay, "2026-10-01")
        // It can overlap where it was, but not other things.
        p = place(p, 8, "stone")
        XCTAssertEqual(p.moving(from: 5, to: 7), p)
        XCTAssertEqual(p.moving(from: 5, to: 4).garden[4]?.itemId, "barn")
    }

    // MARK: Seasons and care

    // The first farm year: spring from 2 November 2026, then a week each of summer, autumn and winter.
    private func nov(_ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 10))!
    }

    private func at(_ farm: Farm, _ cell: Int, _ id: String, _ d: Int) -> Farm {
        var rng = SeededGenerator(seed: UInt64(cell))
        return farm.placing(id, at: cell, now: nov(d), using: &rng)
    }

    func testSeasonsTurnEveryWeekAndBeforeTheFirstFarmYearItIsSpring() {
        XCTAssertEqual(Farm.season(on: day(20)).season, .spring)
        XCTAssertEqual(Farm.season(on: nov(5)), SeasonDay(season: .spring, day: 3, daysLeft: 4, startDay: "2026-11-02"))
        XCTAssertEqual(Farm.season(on: nov(9)).season, .summer)
        XCTAssertEqual(Farm.season(on: nov(16)).season, .autumn)
        XCTAssertEqual(Farm.season(on: nov(23)).season, .winter)
        XCTAssertEqual(Farm.season(on: nov(23)).startDay, "2026-11-23")
        XCTAssertEqual(Farm.season(on: nov(30)).season, .spring)
        XCTAssertEqual(Farm.season(on: nov(30)).startDay, "2026-11-30")
    }

    func testFieldsAndFlowersWitherInWinterAndNothingCanBePlantedUntilSpring() {
        var p = at(rich(), 0, "wheat", 20)
        p = at(p, 1, "flower", 20)
        p = at(p, 2, "appletree", 2)
        XCTAssertEqual(Farm.readyProduce(p.garden[0]!, now: nov(22)), .wheat)
        XCTAssertTrue(Farm.isWithered(p.garden[0]!, now: nov(23)))
        XCTAssertEqual(Farm.picture(of: p.garden[0]!, now: nov(23)), "🍂")
        XCTAssertEqual(Farm.picture(of: p.garden[1]!, now: nov(23)), "🥀")
        XCTAssertNil(Farm.readyProduce(p.garden[0]!, now: nov(23)))
        // Trees survive but rest in winter.
        XCTAssertFalse(Farm.isWithered(p.garden[2]!, now: nov(23)))
        XCTAssertNil(Farm.readyProduce(p.garden[2]!, now: nov(23)))
        XCTAssertEqual(Farm.readyProduce(p.garden[2]!, now: nov(30)), .apple)
        // Still withered in spring until cleared and planted again.
        XCTAssertTrue(Farm.isWithered(p.garden[0]!, now: nov(30)))
        XCTAssertEqual(p.placementProblem(at: 5, itemID: "wheat", now: nov(24)), .winter)
        XCTAssertNotEqual(p.placementProblem(at: 5, itemID: "cow", now: nov(24)), .winter)
        XCTAssertNil(p.placementProblem(at: 5, itemID: "wheat", now: nov(30)))
    }

    // Care tests run in December, after the care start (5 November): spring from 30 November.
    private func dec(_ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: d, hour: 10))!
    }

    private func atDec(_ farm: Farm, _ cell: Int, _ id: String, _ d: Int) -> Farm {
        var rng = SeededGenerator(seed: UInt64(cell))
        return farm.placing(id, at: cell, now: dec(d), using: &rng)
    }

    func testAnimalsGetHungryAndStopWorkingUntilFedFeedingCostsStarsAndGivesXp() {
        var p = atDec(rich(100), 0, "coop", 1)
        p = atDec(p, 2, "rabbit", 1)
        p.walletStars = 100
        let rabbit = p.garden[2]!
        XCTAssertEqual(Farm.readyProduce(rabbit, now: dec(3)), .wool)
        XCTAssertFalse(Farm.needsCare(rabbit, now: dec(3)))
        XCTAssertTrue(Farm.needsCare(rabbit, now: dec(4)), "three days after it came it is hungry …")
        XCTAssertNil(Farm.readyProduce(rabbit, now: dec(4)), "… and gives nothing")
        XCTAssertEqual(Farm.careCells(p.garden, now: dec(4)), [2])
        XCTAssertEqual(Farm.careCost(p.garden, cell: 2, now: dec(4)), 1)
        let fed = p.caring(for: 2, now: dec(4))
        XCTAssertEqual(fed.walletStars, 99)
        XCTAssertEqual(fed.xp, p.xp + 1)
        XCTAssertEqual(fed.garden[2]?.caredDay, "2026-12-04")
        XCTAssertEqual(Farm.readyProduce(fed.garden[2]!, now: dec(4)), .wool)
        XCTAssertEqual(Farm.daysUntilCare(fed.garden[2]!, now: dec(5)), 2)
        // Not enough stars: nothing happens.
        var broke = p
        broke.walletStars = 0
        XCTAssertEqual(broke.caring(for: 2, now: dec(4)), broke)
    }

    func testATractorNeedsAServiceAndBuildingsARepairOrTheyStopHelpingAndMaking() {
        var p = atDec(rich(), 0, "tractor", 1)
        p = atDec(p, 1, "windmill", 1)
        p = atDec(p, 3, "wheat", 1)
        p.goods[.wheat] = 4
        XCTAssertEqual(p.collecting(3, now: dec(4)).goods(.wheat), 6)
        XCTAssertTrue(p.canMake(at: 1, now: dec(4)))
        XCTAssertTrue(Farm.needsCare(p.garden[0]!, now: dec(8)))
        XCTAssertEqual(p.collecting(3, now: dec(8)).goods(.wheat), 5)
        XCTAssertFalse(p.canMake(at: 1, now: dec(15)), "the windmill is due a repair after 14 days")
        let all = p.caringForAll(now: dec(15))
        XCTAssertEqual(Farm.careCells(all.garden, now: dec(15)), [])
        XCTAssertEqual(all.walletStars, p.walletStars - 5 - 6)
        XCTAssertTrue(all.canMake(at: 1, now: dec(15)))
    }

    func testFarmsFromBeforeCareExistedStartFreshAndDecorationsNeverNeedCare() {
        var p = place(rich(), 0, "rabbit") // October, long before the care start
        p = place(p, 1, "stone")
        XCTAssertEqual(Farm.daysUntilCare(p.garden[0]!, now: nov(5)), 3)
        XCTAssertNil(Farm.daysUntilCare(p.garden[1]!, now: nov(5)))
        XCTAssertTrue(GardenItem.all.filter { $0.category == .animals && $0.needs != nil }.allSatisfy { $0.care?.kind == .feed })
    }

    /// `caredDay` and `farmSeason` are stored under the web app's names, and cleared with the progress.
    func testCareAndTheSeasonCardAreStoredLikeTheWebApp() throws {
        let context = try makeContext()
        let child = ChildProfile(name: "Lena", age: 6)
        context.insert(child)
        var farm = child.farm
        farm.garden[0] = GardenPlot(itemId: "rabbit", plantedDay: "2026-11-05", caredDay: "2026-11-08")
        child.setFarm(farm)
        child.farmSeason = "2026-11-02"
        let garden = try XCTUnwrap(BackupExtras.decode(child.backupExtras)["garden"] as? [Any])
        XCTAssertEqual((garden[0] as? [String: Any])?["caredDay"] as? String, "2026-11-08")
        XCTAssertEqual(child.webField("farmSeason", as: String.self), "2026-11-02")
        XCTAssertEqual(child.farm.garden[0]?.caredDay, "2026-11-08")

        ProfileMaintenance.resetProgress(of: child, in: context)
        XCTAssertNil(child.farmSeason)
    }

    // MARK: Garden time

    func testLimitsGardenTimePerDayWithExtraMinutesForTodayOnly() throws {
        let d = { (n: Int) in Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: n, hour: 10))! }
        let context = try makeContext()
        let child = ChildProfile(name: "Emil", age: 8)
        context.insert(child)
        XCTAssertEqual(child.gardenMinutesPerDay, 20)
        var t = child.gardenTime
        XCTAssertEqual(t.secondsLeft(now: d(1)), 20 * 60)
        t = t.adding(seconds: 19 * 60, now: d(1))
        XCTAssertEqual(t.secondsLeft(now: d(1)), 60)
        t = t.adding(seconds: 120, now: d(1))
        XCTAssertEqual(t.secondsLeft(now: d(1)), 0)
        t = t.granting(minutes: 10, now: d(1))
        XCTAssertEqual(t.secondsLeft(now: d(1)), 9 * 60)
        // A new day starts fresh, without yesterday's extra minutes.
        XCTAssertEqual(t.secondsLeft(now: d(2)), 20 * 60)
        let next = t.adding(seconds: 30, now: d(2))
        XCTAssertEqual(next.seconds, 30)
        XCTAssertEqual(next.bonusMinutes, 0)
        var unlimited = t
        unlimited.minutesPerDay = 0
        XCTAssertNil(unlimited.secondsLeft(now: d(1)))

        // Stored under the web app's names.
        child.setGardenTime(t)
        child.gardenMinutesPerDay = 30
        XCTAssertEqual(child.webField("gardenDay", as: String.self), "2026-03-01")
        XCTAssertEqual(child.webField("gardenBonusMinutes", as: Int.self), 10)
        XCTAssertEqual(child.webField("gardenMinutesPerDay", as: Int.self), 30)
        XCTAssertEqual(child.gardenTime.secondsLeft(now: d(1)), 40 * 60 - 21 * 60)
    }

    // MARK: Backups

    /// A garden saved by the web app comes in, is played with here, and goes out in the web app's shape.
    func testAWebGardenRoundTripsThroughABackup() throws {
        let backup = """
        { "app": "funkel", "version": 1, "exportedAt": "2026-10-18T09:00:00.000Z",
          "profiles": [ {
            "id": "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69", "name": "Lena", "age": 6,
            "totalStars": 62, "walletStars": 100,
            "garden": [{ "itemId": "barn", "plantedDay": "2026-10-01" }, null, { "itemId": "cow", "plantedDay": "2026-10-02", "collectedDay": "2026-10-17" },
                       null, { "itemId": "flower", "plantedDay": "2026-10-03", "variant": "🌻" }],
            "gardenColumns": 16, "farmGoods": { "egg": 3, "milk": 1, "wheat": 0, "veg": 0, "apple": 0, "honey": 0 }, "farmXp": 140,
            "farmOrders": { "day": "2026-10-17", "orders": [{ "id": "2026-10-17-0", "wants": { "milk": 2 }, "stars": 1, "xp": 6, "done": true }] },
            "gardenMinutesPerDay": 15, "gardenDay": "2026-10-17", "gardenSeconds": 300, "gardenBonusMinutes": 5
          } ] }
        """
        let context = try makeContext()
        guard case .success(let contents) = Backup.read(Data(backup.utf8)) else { return XCTFail("not readable") }
        let lena = try Backup.restore(contents, into: context)[0]

        let farm = lena.farm
        XCTAssertEqual(farm.garden.count, Farm.startSize)
        XCTAssertEqual(farm.garden[0]?.itemId, "barn")
        XCTAssertEqual(farm.garden[2]?.collectedDay, "2026-10-17")
        XCTAssertEqual(farm.garden[4]?.variant, "🌻")
        XCTAssertEqual(farm.goods(.egg), 3)
        XCTAssertEqual(farm.xp, 140)
        XCTAssertEqual(farm.orders?.orders.first?.isDone, true)
        XCTAssertEqual(farm.walletStars, 100)
        XCTAssertEqual(lena.gardenMinutesPerDay, 15)
        XCTAssertEqual(lena.gardenTime.bonusMinutes, 5)

        // Milk today, then out again.
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 10))!
        lena.setFarm(farm.collecting(2, now: now).placing("stone", at: 6, now: now))
        let out = try JSONSerialization.jsonObject(with: Backup.export([lena])) as! [String: Any]
        let p = (out["profiles"] as! [[String: Any]])[0]
        let garden = p["garden"] as! [Any]
        XCTAssertEqual(garden.count, Farm.startSize)
        XCTAssertTrue(garden[1] is NSNull)
        XCTAssertEqual((garden[0] as! [String: Any]).keys.sorted(), ["itemId", "plantedDay"])
        XCTAssertEqual((garden[2] as! [String: Any])["collectedDay"] as? String, "2026-10-18")
        XCTAssertEqual((garden[4] as! [String: Any])["variant"] as? String, "🌻")
        XCTAssertEqual((garden[6] as! [String: Any])["itemId"] as? String, "stone")
        XCTAssertEqual(p["gardenColumns"] as? Int, 16)
        // Every kind of good is written, like the web app's emptyGoods().
        var goods = Dictionary(uniqueKeysWithValues: Produce.allCases.map { ($0.rawValue, 0) })
        goods["egg"] = 3
        goods["milk"] = 2
        XCTAssertEqual(p["farmGoods"] as? [String: Int], goods)
        XCTAssertEqual(p["farmXp"] as? Int, 140 + 3 + 1)
        XCTAssertEqual(p["walletStars"] as? Int, 99)
        XCTAssertEqual(p["totalStars"] as? Int, 62)
        XCTAssertEqual(p["gardenMinutesPerDay"] as? Int, 15)
        let orders = p["farmOrders"] as! [String: Any]
        XCTAssertEqual(orders["day"] as? String, "2026-10-17")
        XCTAssertEqual(((orders["orders"] as! [[String: Any]])[0])["done"] as? Bool, true)

        // "Fortschritt zurücksetzen" clears the farm like the web app does.
        ProfileMaintenance.resetProgress(of: lena, in: context)
        XCTAssertEqual(lena.farm.garden, Farm.emptyGarden())
        XCTAssertEqual(lena.farm.xp, 0)
        XCTAssertEqual(lena.gardenMinutesPerDay, 15, "a setting, not progress")
    }
}
