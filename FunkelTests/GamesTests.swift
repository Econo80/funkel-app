import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/games.test.ts (tickets, bonus games, difficulty, memory, balloons).
@MainActor
final class GamesTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 10))!
    }

    private func child(_ stars: Int, age: Int = 6) -> PlayState {
        PlayState(age: age, walletStars: stars)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: Tickets

    func testATicketCostsStarsButNeverTheLifetimeTotal() {
        let profile = ChildProfile(name: "Lena", age: 6)
        profile.totalStars = 25
        profile.walletStars = 25
        profile.playState = profile.playState.buyingTicket(day(1), calendar: calendar)
        XCTAssertEqual(profile.walletStars, 15)
        XCTAssertEqual(profile.totalStars, 25)
        XCTAssertEqual(profile.playState.gamesToday, 1)
        XCTAssertEqual(profile.webField("gameDay", as: String.self), "2026-10-01")
    }

    func testExplainsWhyAGameCantStart() {
        XCTAssertEqual(child(4).checkTicket(day(1), calendar: calendar), .notEnoughStars(missing: 6))
        var off = child(50)
        off.gamesEnabled = false
        XCTAssertEqual(off.checkTicket(day(1), calendar: calendar), .disabled)

        var p = child(100)
        for _ in 0..<3 { p = p.buyingTicket(day(1), calendar: calendar) }
        XCTAssertEqual(p.checkTicket(day(1), calendar: calendar), .dailyLimit)
        XCTAssertEqual(p.buyingTicket(day(1), calendar: calendar), p)
        XCTAssertEqual(p.gamesLeftToday(day(1), calendar: calendar), 0)
    }

    func testOpensAgainTheNextDayAndSupportsNoLimit() {
        var p = child(100)
        for _ in 0..<3 { p = p.buyingTicket(day(1), calendar: calendar) }
        XCTAssertTrue(p.checkTicket(day(2), calendar: calendar).isOK)
        XCTAssertEqual(p.gamesLeftToday(day(2), calendar: calendar), 3)

        var unlimited = child(100)
        unlimited.gamesPerDay = 0
        for _ in 0..<8 { unlimited = unlimited.buyingTicket(day(1), calendar: calendar) }
        XCTAssertEqual(unlimited.walletStars, 20)
        XCTAssertNil(unlimited.gamesLeftToday(day(1), calendar: calendar))
    }

    // MARK: Bonus games

    func testBonusGamesAreFreeSkipTheLimitAndExpireAtMidnight() {
        var p = child(0)
        for _ in 0..<3 {
            p.walletStars = 100
            p = p.buyingTicket(day(1), calendar: calendar)
        }
        p.walletStars = 0
        XCTAssertEqual(p.checkTicket(day(1), calendar: calendar), .dailyLimit)

        p = p.grantingBonusGames(2, now: day(1), calendar: calendar)
        XCTAssertEqual(p.bonusGamesLeftToday(day(1), calendar: calendar), 2)
        XCTAssertEqual(p.checkTicket(day(1), calendar: calendar), .ok(free: true))
        p = p.buyingTicket(day(1), calendar: calendar)
        XCTAssertEqual(p.walletStars, 0)
        XCTAssertEqual(p.bonusGamesLeftToday(day(1), calendar: calendar), 1)
        XCTAssertEqual(p.bonusGamesLeftToday(day(2), calendar: calendar), 0)
    }

    func testBonusGamesAddUpButAreCapped() {
        let p = child(0).grantingBonusGames(3, now: day(1), calendar: calendar).grantingBonusGames(3, now: day(1), calendar: calendar)
        XCTAssertEqual(p.bonusGamesLeftToday(day(1), calendar: calendar), 6)
        XCTAssertEqual(p.grantingBonusGames(50, now: day(1), calendar: calendar).bonusGamesLeftToday(day(1), calendar: calendar), 10)
    }

    // MARK: Difficulty

    func testDifficultyShiftsTheGamesTwoYearsEitherWay() {
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .normal), 5)
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .hard), 7)
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .easy), 4)
        XCTAssertEqual(Games.gameAge(age: 14, difficulty: .hard), 14)
    }

    func testMemoryStartsAFiveYearOldAtSixPairsAndGrowsEachBoard() {
        var rng = SeededGenerator(seed: 8)
        XCTAssertEqual(Memory.board(age: 5, using: &rng).count, 12)
        XCTAssertEqual(Memory.board(age: 5, boardsCleared: 1, using: &rng).count, 16)
        XCTAssertEqual(Memory.board(age: 5, boardsCleared: 99, using: &rng).count, 30)
    }

    // MARK: Memory

    func testMemoryDealsPairsThatGrowWithAge() {
        var rng = SeededGenerator(seed: 3)
        for age in [4, 6, 9, 13] {
            let board = Memory.board(age: age, using: &rng)
            XCTAssertEqual(board.count, Memory.pairs(forAge: age) * 2)
            XCTAssertEqual(Set(board.map(\.id)).count, board.count)
            let counts = Dictionary(grouping: board, by: \.picture).mapValues(\.count)
            XCTAssertTrue(counts.values.allSatisfy { $0 == 2 }, "age \(age)")
        }
        XCTAssertLessThan(Memory.pairs(forAge: 4), Memory.pairs(forAge: 12))
    }

    // MARK: Balloons

    func testBalloonRulesSuitTheAgeAndAreAlwaysCorrect() {
        var rng = SeededGenerator(seed: 5)
        XCTAssertEqual(Balloons.rule(forAge: 4, using: &rng), .all)
        if case .color = Balloons.rule(forAge: 5, using: &rng) {} else { XCTFail("5-year-olds pop by colour") }
        XCTAssertEqual(Balloons.rule(forAge: 8, using: &rng), .even)
        let rule = Balloons.rule(forAge: 11, using: &rng)
        guard case .product(let target) = rule else { return XCTFail("11-year-olds pop by product") }

        var good = 0
        for _ in 0..<400 {
            let b = Balloons.spawn(rule, using: &rng)
            let factors = (b.label ?? "").split(separator: "·").compactMap { Int($0) }
            XCTAssertEqual(factors.count, 2)
            XCTAssertEqual(b.good, factors.reduce(1, *) == target)
            if b.good { good += 1 }
        }
        XCTAssertGreaterThan(good, 80)

        for _ in 0..<200 {
            let b = Balloons.spawn(.even, using: &rng)
            XCTAssertEqual(b.good, Int(b.label ?? "")!.isMultiple(of: 2))
        }
    }

    func testFiveAndSixYearOldsLookForAColourAmongPlentyOfWrongOnes() {
        var rng = SeededGenerator(seed: 9)
        var good = 0
        for _ in 0..<400 {
            let b = Balloons.spawn(.color(.red), using: &rng)
            XCTAssertEqual(b.good, b.color == .red)
            if b.good { good += 1 }
        }
        XCTAssertGreaterThan(good, 120)
        XCTAssertLessThan(good, 200)
        for _ in 0..<20 { XCTAssertNotEqual(Balloons.nextColor(after: .blue, using: &rng), .blue) }
    }

    func testAPoppedBalloonScoresAndAWrongOneCostsAPointButNeverBelowZero() {
        var score = GameScore()
        score.add(-1)
        XCTAssertEqual(score.points, 0)
        score.add(1)
        score.add(1)
        score.add(-1)
        XCTAssertEqual(score.points, 1)
    }

    // MARK: Storage

    func testDefaultsMatchTheWebApp() {
        let p = ChildProfile(name: "Ida", age: 7).playState
        XCTAssertTrue(p.gamesEnabled)
        XCTAssertEqual(p.gameCost, 10)
        XCTAssertEqual(p.gamesPerDay, 3)
        XCTAssertEqual(p.gameDifficulty, .normal)
        XCTAssertEqual(p.gamesToday, 0)
        XCTAssertEqual(p.bonusGames, 0)
    }

    func testGameFieldsRoundTripThroughABackupInTheWebShape() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Ida", age: 9)
        context.insert(profile)
        profile.walletStars = 40
        profile.setGameSettings(enabled: false, cost: 15, perDay: 0, difficulty: .hard)
        var state = profile.playState
        state.gamesEnabled = true
        state = state.buyingTicket(day(3), calendar: calendar).grantingBonusGames(2, now: day(3), calendar: calendar)
        profile.playState = state

        let data = try Backup.export([profile], calendar: calendar)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let p = try XCTUnwrap((root["profiles"] as? [[String: Any]])?.first)
        XCTAssertEqual(p["gamesEnabled"] as? Bool, true)
        XCTAssertEqual(p["gameCost"] as? Int, 15)
        XCTAssertEqual(p["gamesPerDay"] as? Int, 0)
        XCTAssertEqual(p["gameDifficulty"] as? String, "hard")
        XCTAssertEqual(p["gameDay"] as? String, "2026-10-03")
        XCTAssertEqual(p["gamesToday"] as? Int, 1)
        XCTAssertEqual(p["bonusGames"] as? Int, 2)
        XCTAssertEqual(p["bonusDay"] as? String, "2026-10-03")
        XCTAssertEqual(p["walletStars"] as? Int, 25)

        guard case .success(let contents) = Backup.read(data) else { return XCTFail("backup unreadable") }
        let restoreContext = try makeContext()
        let restored = try XCTUnwrap(Backup.restore(contents, into: restoreContext, calendar: calendar).first)
        XCTAssertEqual(restored.playState, profile.playState)

        // A grown-up reset clears today's tickets but keeps the settings.
        ProfileMaintenance.resetProgress(of: restored, in: restoreContext)
        XCTAssertEqual(restored.playState.gamesToday, 0)
        XCTAssertNil(restored.playState.gameDay)
        XCTAssertEqual(restored.playState.bonusGames, 0)
        XCTAssertEqual(restored.playState.gameCost, 15)
    }
}
