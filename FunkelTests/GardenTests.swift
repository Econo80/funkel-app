import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/garden.test.ts and the garden-time test in
/// web/tests/profile-and-round.test.ts: the same farm rules in both apps.
@MainActor
final class GardenTests: XCTestCase {

    private let columns = Garden.columns

    private func day(_ d: Int, hour: Int = 10) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
    }

    /// A farm far enough along that every item is unlocked.
    private func rich(_ stars: Int = 500) -> Farm {
        var farm = Farm(profileID: "lena", walletStars: stars)
        farm.xp = 5000
        return farm
    }

    private func place(_ farm: Farm, _ cell: Int, _ id: String, _ d: Int = 1) -> Farm {
        farm.placing(id, at: cell, now: day(d), rng: GardenRandom(seed: Int32(cell)))
    }

    // MARK: Farm buildings

    func testBuildingsTakeDaysAndBigOnesCoverSeveralSquares() {
        let p = place(rich(), 0, "barn")
        XCTAssertEqual(p.walletStars, 460)
        XCTAssertEqual(p.garden[0]?.picture(now: day(1)), "🚧")
        XCTAssertEqual(p.garden[0]?.daysUntilNextStage(now: day(1)), 2)
        XCTAssertEqual(p.garden[0]?.picture(now: day(3)), "art:barn")
        let covered = p.garden.occupancy()
        XCTAssertEqual([0, 1, columns, columns + 1].map { covered[$0] }, [0, 0, 0, 0])
        XCTAssertNil(covered[2])
        // Nothing else fits on top of it.
        XCTAssertEqual(p.placementProblem(at: columns + 1, itemID: "stone", now: day(1)), .space)
    }

    func testBigItemsShiftLeftOrUpToFitAtTheEdge() {
        let p = place(rich(), columns - 1, "pond")
        XCTAssertEqual(p.garden[columns - 2]?.itemID, "pond")
        let bottomRight = Garden.startSize - 1
        let q = place(rich(), bottomRight, "barn")
        XCTAssertEqual(q.garden[bottomRight - columns - 1]?.itemID, "barn")
    }

    // MARK: Farm animals

    func testFarmAnimalsNeedAFinishedHomeWithRoom() {
        var p = rich()
        XCTAssertEqual(p.placementProblem(at: 5, itemID: "cow", now: day(1)), .home)
        p = place(p, 0, "barn")
        XCTAssertEqual(p.placementProblem(at: 5, itemID: "cow", now: day(2)), .home) // still being built
        for (i, id) in ["cow", "pig", "sheep", "horse"].enumerated() { p = place(p, 2 + i, id, 3) }
        XCTAssertEqual(p.garden.homeSpace(.farm, now: day(3)), Garden.HomeSpace(capacity: 4, used: 4))
        XCTAssertEqual(p.placementProblem(at: 12, itemID: "goat", now: day(3)), .full)
        // A full home can't be cleared away from under its animals.
        XCTAssertFalse(p.canClear(0, now: day(3)))
        XCTAssertEqual(p.clearing(0, now: day(3)), p)
        XCTAssertFalse(p.clearing(2, now: day(3)).canClear(0, now: day(3)))
    }

    func testSmallAnimalsLiveAnywhereAndAHouseIsHomeForCats() {
        var p = place(rich(), 0, "rabbit")
        XCTAssertEqual(p.garden[0]?.itemID, "rabbit")
        XCTAssertEqual(p.placementProblem(at: 1, itemID: "cat", now: day(1)), .home)
        p = place(p, 1, "house")
        XCTAssertNil(p.placementProblem(at: 2, itemID: "cat", now: day(1)))
    }

    func testChicksGrowIntoHensThatLayOneEggADay() {
        var p = place(place(rich(), 0, "coop"), 1, "chick", 2)
        XCTAssertEqual(p.garden[1]?.picture(now: day(2)), "🐣")
        XCTAssertEqual(p.garden[1]?.picture(now: day(4)), "🐥")
        XCTAssertNil(p.garden[1]?.readyProduce(now: day(4)))
        XCTAssertEqual(p.garden[1]?.picture(now: day(6)), "🐔")
        XCTAssertEqual(p.garden[1]?.readyProduce(now: day(6)), .egg)
        p = p.collecting(1, now: day(6))
        XCTAssertEqual(p.goods(.egg), 1)
        XCTAssertNil(p.garden[1]?.readyProduce(now: day(6)))
        XCTAssertEqual(p.collecting(1, now: day(6)), p)
        XCTAssertEqual(p.garden[1]?.readyProduce(now: day(7)), .egg)
    }

    func testCowsGiveMilkFromTheDayAfterTheyArrive() {
        var p = place(place(rich(), 0, "barn"), 2, "cow", 3)
        XCTAssertNil(p.garden[2]?.readyProduce(now: day(3)))
        p = p.collecting(2, now: day(4))
        XCTAssertEqual(p.goods(.milk), 1)
    }

    func testSellsGoodsInFivesForSpendableStarsOnly() {
        var p = rich(10)
        p.goods[.egg] = 7
        p.goods[.milk] = 4
        let sold = p.sellingGoods()
        XCTAssertEqual(sold.walletStars, 12)
        XCTAssertEqual(sold.goods(.egg), 0)
        XCTAssertEqual(sold.goods(.milk), 1)
        XCTAssertEqual(sold.sellingGoods(), sold)

        // Lifetime stars stay learning stars: only the wallet grows.
        let profile = ChildProfile(name: "Lena", age: 6)
        profile.totalStars = 50
        profile.saveFarm(sold)
        XCTAssertEqual(profile.walletStars, 12)
        XCTAssertEqual(profile.totalStars, 50)
    }

    // MARK: More land

    func testLandAddsFourRowsAtATimeThreeTimes() {
        var p = rich(200)
        XCTAssertEqual(p.garden.rows, 8)
        for price in [25, 40, 60] {
            XCTAssertEqual(p.garden.nextLandPrice, price)
            let before = p.walletStars
            p = p.buyingLand()
            XCTAssertEqual(p.walletStars, before - price)
        }
        XCTAssertEqual(p.garden.rows, 20)
        XCTAssertNil(p.garden.nextLandPrice)
        XCTAssertEqual(p.buyingLand(), p)
    }

    func testOldSixColumnGardensMoveIntoTheWideFarmKeepingLand() {
        let old = ChildProfile(name: "Alt", age: 7)
        old.backupExtras = BackupExtras.encode(["id": "x", "garden": [["itemId": "flower", "plantedDay": "2026-10-01"]]])
        let farm = old.loadFarm()
        XCTAssertEqual(farm.garden.count, Garden.startSize)
        XCTAssertEqual(farm.garden[0]?.itemID, "flower")
        XCTAssertEqual(farm.goods, Farm.emptyGoods)

        // 6 columns × 6 rows = one land purchase; a barn at row 1, column 4.
        var legacy: [Any] = Array(repeating: NSNull(), count: 36)
        legacy[6 + 4] = ["itemId": "barn", "plantedDay": "2026-10-01"]
        legacy[35] = ["itemId": "stone", "plantedDay": "2026-10-01"]
        let profile = ChildProfile(name: "Ida", age: 8)
        profile.backupExtras = BackupExtras.encode(["id": "y", "garden": legacy])
        let moved = profile.loadFarm()
        XCTAssertEqual(moved.garden.rows, 12)
        XCTAssertEqual(moved.garden[columns + 4]?.itemID, "barn")
        XCTAssertEqual(moved.garden[5 * columns + 5]?.itemID, "stone")
        XCTAssertEqual(moved.garden.nextLandPrice, 40)
        // Saved again, it is not moved a second time.
        profile.saveFarm(moved)
        XCTAssertEqual(profile.webField("gardenColumns", as: Int.self), columns)
        XCTAssertEqual(profile.loadFarm().garden, moved.garden)
    }

    func testEveryItemHasAPictureAndAPrice() {
        for item in GardenCatalog.items {
            XCTAssertEqual(item.stages.count, item.days.count, item.id)
            XCTAssertGreaterThanOrEqual(item.price, item.connects ? 0 : 1, item.id)
            XCTAssertEqual(item.price == 0, item.category == .paths, item.id)
            if let needs = item.needs {
                XCTAssertTrue(GardenCatalog.items.contains { $0.houses == needs }, item.id)
            }
        }
        XCTAssertEqual(Set(GardenCatalog.items.map(\.id)).count, GardenCatalog.items.count)
    }

    // MARK: Roads, paths and fences

    func testRoadsAreFreeAndJoinUpWithTheirNeighbours() {
        var p = rich(0)
        for cell in [0, 1, 2, 2 + columns] { p = place(p, cell, "road") }
        p = place(p, 3, "fence")
        XCTAssertEqual(p.walletStars, 0)
        XCTAssertEqual(p.garden.connections(at: 0), Garden.Links(n: false, e: true, s: false, w: false))
        XCTAssertEqual(p.garden.connections(at: 2), Garden.Links(n: false, e: false, s: true, w: true))
        // A road doesn't join a fence; the right edge doesn't wrap to the next row.
        XCTAssertEqual(p.garden.connections(at: 3), Garden.Links())
        let edge = place(place(rich(0), columns - 1, "path"), columns, "path")
        XCTAssertFalse(edge.garden.connections(at: columns - 1).e)
    }

    // MARK: Farm levels

    private func fresh() -> Farm { Farm(profileID: "emil", walletStars: 300) }

    func testLevelsGrowWithXpAndUnlockItemsStepByStep() {
        XCTAssertEqual(FarmLevels.level(for: 0), FarmLevels.Level(level: 1, xpInLevel: 0, xpForNext: 10))
        XCTAssertEqual(FarmLevels.level(for: 35).level, 3)
        XCTAssertEqual(FarmLevels.level(for: 460).level, 10)
        XCTAssertEqual(FarmLevels.level(for: 560).level, 11)
        XCTAssertTrue(GardenCatalog.unlocked(at: 4).map(\.id).contains("barn"))
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

    func testFarmsBuiltBeforeLevelsExistedAreCredited() {
        var g = Garden.empty()
        g[0] = GardenPlot(itemID: "barn", plantedDay: "2026-10-01")
        g[5] = GardenPlot(itemID: "cow", plantedDay: "2026-10-01")
        XCTAssertEqual(g.startingFarmXp, 65)
        let old = ChildProfile(name: "Zoe", age: 9)
        old.backupExtras = BackupExtras.encode([
            "id": "z", "gardenColumns": columns,
            "garden": [["itemId": "barn", "plantedDay": "2026-10-01"], NSNull(), NSNull(), NSNull(), NSNull(), ["itemId": "cow", "plantedDay": "2026-10-01"]],
        ])
        let farm = old.loadFarm()
        XCTAssertEqual(farm.xp, 65)
        XCTAssertGreaterThanOrEqual(farm.level.level, 4) // keeps barn-level items
    }

    // MARK: Harvest

    func testCollectsGrownCropsWhichThenGrowAgain() {
        var p = place(rich(), 0, "wheat")
        XCTAssertNil(p.garden[0]?.readyProduce(now: day(1)))
        XCTAssertEqual(p.garden[0]?.readyProduce(now: day(2)), .wheat)
        p = p.collecting(0, now: day(2))
        XCTAssertEqual(p.goods(.wheat), 1)
        XCTAssertEqual(p.garden[0]?.picture(now: day(2)), "🌱")
        XCTAssertEqual(p.garden[0]?.readyProduce(now: day(3)), .wheat)
    }

    func testListsEverythingReadyToCollect() {
        var p = place(place(rich(), 0, "wheat"), 1, "beehive")
        p = place(p, 2, "appletree")
        XCTAssertEqual(p.garden.readyCells(now: day(1)), [])
        XCTAssertEqual(p.garden.readyCells(now: day(2)), [0, 1])
        XCTAssertEqual(p.garden.readyCells(now: day(5)), [0, 1, 2])
    }

    // MARK: Orders

    func testOrdersAskForGoodsTheFarmCanMakeAndPayBetterThanTheShop() {
        XCTAssertEqual(rich().withTodaysOrders(now: day(1)).orders?.orders, [])
        var p = place(place(rich(), 0, "coop"), 1, "chick", 2).withTodaysOrders(now: day(2))
        let orders = p.orders!.orders
        XCTAssertEqual(orders.count, 3)
        for order in orders {
            XCTAssertEqual(Array(order.wants.keys), [.egg])
            XCTAssertGreaterThanOrEqual(order.stars, 1 + order.wants[.egg]! / 3)
        }
        // The same orders all day long.
        XCTAssertEqual(p.withTodaysOrders(now: day(2)), p)
        XCTAssertNotEqual(p.withTodaysOrders(now: day(3)).orders!.day, p.orders!.day)

        let order = orders[0]
        XCTAssertEqual(p.fulfilling(order.id), p) // not enough eggs yet
        p.goods[.egg] = 10
        let before = p.walletStars
        let done = p.fulfilling(order.id)
        XCTAssertEqual(done.walletStars, before + order.stars)
        XCTAssertEqual(done.goods(.egg), 10 - order.wants[.egg]!)
        XCTAssertEqual(done.orders!.orders[0].done, true)
        XCTAssertEqual(done.fulfilling(order.id), done)
    }

    /// The same child gets the same orders on the same day in both apps
    /// (expected values computed with web/src/domain/garden.ts).
    func testOrdersMatchTheWebApp() {
        let rng = GardenRandom(seed: 42)
        XCTAssertEqual(rng.next(), 0.6011037519201636, accuracy: 1e-12)
        XCTAssertEqual(rng.next(), 0.44829055899754167, accuracy: 1e-12)
        XCTAssertEqual(rng.next(), 0.8524657934904099, accuracy: 1e-12)
        XCTAssertEqual(GardenRandom.hash("lena:2026-10-02"), -1_748_589_492)
        XCTAssertEqual(GardenRandom.hash("3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69:2026-10-18"), -414_867_618)

        var farm = rich()
        farm.garden[0] = GardenPlot(itemID: "coop", plantedDay: "2026-10-01")
        farm.garden[1] = GardenPlot(itemID: "chick", plantedDay: "2026-10-02")
        farm.garden[2] = GardenPlot(itemID: "cow", plantedDay: "2026-10-02")
        let orders = farm.withTodaysOrders(now: day(2)).orders
        XCTAssertEqual(orders, FarmOrders(day: "2026-10-02", orders: [
            FarmOrder(id: "2026-10-02-0", wants: [.milk: 3], stars: 2, xp: 9),
            FarmOrder(id: "2026-10-02-1", wants: [.egg: 4], stars: 2, xp: 12),
            FarmOrder(id: "2026-10-02-2", wants: [.egg: 3], stars: 2, xp: 9),
        ]))
    }

    // MARK: Moving

    func testMovesAnItemBigOnesTooKeepingItsAge() {
        var p = place(rich(), 0, "barn")
        p = p.moving(from: columns + 1, to: 5)
        XCTAssertNil(p.garden[0])
        XCTAssertEqual(p.garden[5]?.itemID, "barn")
        XCTAssertEqual(p.garden[5]?.plantedDay, "2026-10-01")
        // It can overlap where it was, but not other things.
        p = place(p, 8, "stone")
        XCTAssertEqual(p.moving(from: 5, to: 7), p)
        XCTAssertEqual(p.moving(from: 5, to: 4).garden[4]?.itemID, "barn")
    }

    // MARK: Garden time (web/tests/profile-and-round.test.ts)

    func testLimitsGardenTimePerDayWithExtraMinutesForTodayOnly() {
        let profile = ChildProfile(name: "Emil", age: 8)
        var p = profile.loadFarm()
        XCTAssertEqual(p.minutesPerDay, 20)
        XCTAssertEqual(p.gardenSecondsLeft(now: day(1)), 20 * 60)
        p = p.addingGardenTime(19 * 60, now: day(1))
        XCTAssertEqual(p.gardenSecondsLeft(now: day(1)), 60)
        p = p.addingGardenTime(120, now: day(1))
        XCTAssertEqual(p.gardenSecondsLeft(now: day(1)), 0)
        p = p.grantingGardenMinutes(10, now: day(1))
        XCTAssertEqual(p.gardenSecondsLeft(now: day(1)), 9 * 60)
        // A new day starts fresh, without yesterday's extra minutes.
        XCTAssertEqual(p.gardenSecondsLeft(now: day(2)), 20 * 60)
        let tomorrow = p.addingGardenTime(30, now: day(2))
        XCTAssertEqual(tomorrow.gardenSeconds, 30)
        XCTAssertEqual(tomorrow.gardenBonusMinutes, 0)
        var unlimited = p
        unlimited.minutesPerDay = 0
        XCTAssertNil(unlimited.gardenSecondsLeft(now: day(1)))

        profile.gardenMinutesPerDay = 45
        XCTAssertEqual(profile.loadFarm().minutesPerDay, 45)
        XCTAssertEqual(profile.webField("gardenMinutesPerDay", as: Int.self), 45)
    }

    // MARK: Backups

    /// A farm saved by the web app comes back out of this app unchanged, under
    /// the web app's names and shapes.
    func testWebGardenSurvivesABackupRoundTrip() throws {
        let web = """
        { "app": "funkel", "version": 1, "exportedAt": "2026-10-18T09:00:00.000Z",
          "profiles": [ { "id": "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69", "name": "Lena", "age": 6,
            "totalStars": 62, "walletStars": 123, "gardenMinutesPerDay": 30,
            "garden": [{ "itemId": "barn", "plantedDay": "2026-10-14" }, null, { "itemId": "cow", "plantedDay": "2026-10-16", "collectedDay": "2026-10-17" },
                       { "itemId": "flower", "plantedDay": "2026-10-10", "variant": "🌻" }],
            "gardenColumns": 16, "farmGoods": { "egg": 3, "milk": 1, "wheat": 0, "veg": 0, "apple": 0, "honey": 2 }, "farmXp": 140,
            "farmOrders": { "day": "2026-10-18", "orders": [{ "id": "2026-10-18-0", "wants": { "milk": 2, "egg": 3 }, "stars": 2, "xp": 15, "done": true }] },
            "gardenDay": "2026-10-18", "gardenSeconds": 300, "gardenBonusMinutes": 5 } ] }
        """
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        guard case .success(let contents) = Backup.read(Data(web.utf8)) else { return XCTFail("not read") }
        let lena = try Backup.restore(contents, into: context)[0]

        var farm = lena.loadFarm()
        XCTAssertEqual(farm.profileID, "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69")
        XCTAssertEqual(farm.walletStars, 123)
        XCTAssertEqual(farm.garden.count, Garden.startSize)
        XCTAssertEqual(farm.garden[2], GardenPlot(itemID: "cow", plantedDay: "2026-10-16", collectedDay: "2026-10-17"))
        XCTAssertEqual(farm.garden[3]?.variant, "🌻")
        XCTAssertEqual(farm.goods(.honey), 2)
        XCTAssertEqual(farm.xp, 140)
        XCTAssertEqual(farm.orders?.orders.first?.wants, [.milk: 2, .egg: 3])
        XCTAssertEqual(farm.minutesPerDay, 30)
        XCTAssertEqual(farm.gardenSeconds, 300)
        XCTAssertEqual(farm.gardenBonusMinutes, 5)

        // Play a little, save, and export again.
        farm = farm.placing("stone", at: 20, now: day(18), rng: GardenRandom(seed: 1))
        lena.saveFarm(farm)
        let exported = try JSONSerialization.jsonObject(with: Backup.export([lena])) as! [String: Any]
        let profile = (exported["profiles"] as! [[String: Any]])[0]
        XCTAssertEqual(profile["walletStars"] as? Int, 122)
        XCTAssertEqual(profile["totalStars"] as? Int, 62)
        XCTAssertEqual(profile["farmXp"] as? Int, 141)
        XCTAssertEqual(profile["gardenColumns"] as? Int, 16)
        XCTAssertEqual(profile["gardenMinutesPerDay"] as? Int, 30)
        let garden = profile["garden"] as! [Any]
        XCTAssertEqual(garden.count, Garden.startSize)
        XCTAssertTrue(garden[1] is NSNull)
        XCTAssertEqual(garden[0] as? [String: String], ["itemId": "barn", "plantedDay": "2026-10-14"])
        XCTAssertEqual(garden[2] as? [String: String], ["itemId": "cow", "plantedDay": "2026-10-16", "collectedDay": "2026-10-17"])
        XCTAssertEqual((garden[20] as? [String: String])?["itemId"], "stone")
        XCTAssertEqual(profile["farmGoods"] as? [String: Int], ["egg": 3, "milk": 1, "wheat": 0, "veg": 0, "apple": 0, "honey": 2])
        let orders = profile["farmOrders"] as? [String: Any]
        XCTAssertEqual(orders?["day"] as? String, "2026-10-18")
        let order = (orders?["orders"] as? [[String: Any]])?.first
        XCTAssertEqual(order?["wants"] as? [String: Int], ["milk": 2, "egg": 3])
        XCTAssertEqual(order?["done"] as? Bool, true)

        // Read back in, the farm is the same.
        guard case .success(let again) = Backup.read(try Backup.export([lena])) else { return XCTFail("not read") }
        let restored = try Backup.restore(again, into: context)[0]
        XCTAssertEqual(restored.loadFarm(), farm)
    }

    /// "Fortschritt zurücksetzen" clears the farm and its store, like the web app.
    func testResetClearsTheFarm() throws {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let profile = ChildProfile(name: "Finn", age: 8)
        context.insert(profile)
        var farm = place(rich(), 0, "wheat")
        farm.goods[.egg] = 4
        profile.saveFarm(farm)
        ProfileMaintenance.resetProgress(of: profile, in: context)
        let cleared = profile.loadFarm()
        XCTAssertEqual(cleared.garden, Garden.empty())
        XCTAssertEqual(cleared.goodsCount, 0)
        XCTAssertEqual(cleared.xp, 0)
        XCTAssertNil(cleared.orders)
    }
}
