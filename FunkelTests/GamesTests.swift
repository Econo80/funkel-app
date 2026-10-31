import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/games.test.ts: tickets, bonus games, difficulty, Memory and Ballon-Pop.
@MainActor
final class GamesTests: XCTestCase {

    private func day(_ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 10))!
    }

    private func child(_ stars: Int, age: Int = 6, _ change: (inout PlayState) -> Void = { _ in }) -> PlayState {
        var state = PlayState(age: age, walletStars: stars)
        change(&state)
        return state
    }

    // MARK: Tickets

    func testATicketCostsStarsButNeverTheLifetimeTotal() throws {
        let profile = ChildProfile(name: "Lena", age: 6)
        profile.totalStars = 25
        profile.walletStars = 25
        profile.playState = profile.playState.buyingTicket(day(1))
        XCTAssertEqual(profile.walletStars, 15)
        XCTAssertEqual(profile.totalStars, 25)
        XCTAssertEqual(profile.playState.gamesToday, 1)
        XCTAssertEqual(profile.webField("gamesToday", as: Int.self), 1)
        XCTAssertEqual(profile.webField("gameDay", as: String.self), Backup.dayKey(day(1)))
    }

    func testExplainsWhyAGameCantStart() {
        XCTAssertEqual(child(4).checkTicket(day(1)), .notEnoughStars(missing: 6))
        XCTAssertEqual(child(50) { $0.gamesEnabled = false }.checkTicket(day(1)), .disabled)
        var p = child(100)
        for _ in 0..<3 { p = p.buyingTicket(day(1)) }
        XCTAssertEqual(p.checkTicket(day(1)), .dailyLimit)
        XCTAssertEqual(p.buyingTicket(day(1)), p)
        XCTAssertEqual(p.gamesLeftToday(day(1)), 0)
    }

    func testOpensAgainTheNextDayAndSupportsNoLimit() {
        var p = child(100)
        for _ in 0..<3 { p = p.buyingTicket(day(1)) }
        XCTAssertTrue(p.checkTicket(day(2)).isOK)
        XCTAssertEqual(p.gamesLeftToday(day(2)), 3)

        var unlimited = child(100) { $0.gamesPerDay = 0 }
        for _ in 0..<8 { unlimited = unlimited.buyingTicket(day(1)) }
        XCTAssertEqual(unlimited.walletStars, 20)
        XCTAssertNil(unlimited.gamesLeftToday(day(1)))
    }

    // MARK: Bonus games

    func testBonusGamesAreFreeSkipTheLimitAndExpireAtMidnight() {
        var p = child(0)
        for _ in 0..<3 {
            p.walletStars = 100
            p = p.buyingTicket(day(1))
        }
        p.walletStars = 0
        XCTAssertEqual(p.checkTicket(day(1)), .dailyLimit)

        p = p.grantingBonusGames(2, now: day(1))
        XCTAssertEqual(p.bonusGamesLeftToday(day(1)), 2)
        XCTAssertEqual(p.checkTicket(day(1)), .ok(free: true))
        p = p.buyingTicket(day(1))
        XCTAssertEqual(p.walletStars, 0)
        XCTAssertEqual(p.bonusGamesLeftToday(day(1)), 1)
        XCTAssertEqual(p.bonusGamesLeftToday(day(2)), 0)
    }

    func testBonusGamesAddUpButAreCapped() {
        let p = child(0).grantingBonusGames(3, now: day(1)).grantingBonusGames(3, now: day(1))
        XCTAssertEqual(p.bonusGamesLeftToday(day(1)), 6)
        XCTAssertEqual(p.grantingBonusGames(50, now: day(1)).bonusGamesLeftToday(day(1)), 10)
    }

    // MARK: Difficulty

    func testDifficultyShiftsTheGamesTwoYearsEitherWay() {
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .normal), 5)
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .hard), 7)
        XCTAssertEqual(Games.gameAge(age: 5, difficulty: .easy), 4)
        XCTAssertEqual(Games.gameAge(age: 14, difficulty: .hard), 14)
        XCTAssertEqual(child(0, age: 8) { $0.gameDifficulty = .easy }.gameAge, 6)
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
        XCTAssertEqual([4, 5, 6, 7, 8, 10, 11, 14].map(Memory.pairs(forAge:)), [4, 6, 8, 8, 10, 10, 12, 12])
    }

    // MARK: Ballon-Pop

    func testBalloonRulesSuitTheAgeAndAreAlwaysCorrect() throws {
        var rng = SeededGenerator(seed: 5)
        XCTAssertEqual(Balloons.rule(forAge: 4, using: &rng), .all)
        guard case .color = Balloons.rule(forAge: 5, using: &rng) else { return XCTFail("5-year-olds pop by colour") }
        XCTAssertEqual(Balloons.rule(forAge: 8, using: &rng), .even)
        let rule = Balloons.rule(forAge: 11, using: &rng)
        guard case .product(let target) = rule else { return XCTFail("older children pop by a product") }

        var good = 0
        for _ in 0..<400 {
            let balloon = Balloons.spawn(rule, using: &rng)
            let factors = try XCTUnwrap(balloon.label).split(separator: "·").compactMap { Int($0) }
            XCTAssertEqual(factors.count, 2)
            XCTAssertEqual(balloon.good, factors.reduce(1, *) == target)
            if balloon.good { good += 1 }
        }
        XCTAssertGreaterThan(good, 80)

        for _ in 0..<200 {
            let balloon = Balloons.spawn(.even, using: &rng)
            XCTAssertEqual(balloon.good, try XCTUnwrap(Int(balloon.label ?? "")).isMultiple(of: 2))
        }
        XCTAssertTrue(Balloons.spawn(.all, using: &rng).good)
    }

    func testFiveAndSixYearOldsLookForAColourWithPlentyOfWrongOnes() {
        var rng = SeededGenerator(seed: 9)
        var good = 0
        for _ in 0..<400 {
            let balloon = Balloons.spawn(.color(.red), using: &rng)
            XCTAssertEqual(balloon.good, balloon.color == .red)
            if balloon.good { good += 1 }
        }
        XCTAssertGreaterThan(good, 120)
        XCTAssertLessThan(good, 200)
        for _ in 0..<20 {
            XCTAssertNotEqual(Balloons.nextColor(after: .blue, using: &rng), .blue)
        }
    }

    func testAWrongBalloonCostsAPointButTheScoreNeverDropsBelowZero() {
        let field = BalloonField(age: 8)
        let size = CGSize(width: 400, height: 600)
        // Let balloons float up for a few seconds, one frame at a time.
        var now = day(1)
        for _ in 0..<240 {
            now = now.addingTimeInterval(1.0 / 60)
            field.step(to: now)
        }
        var points = 0
        var popped = 0
        for y in stride(from: 0.0, to: 600, by: 20) {
            for x in stride(from: 0.0, to: 400, by: 20) {
                guard let balloon = field.pop(at: CGPoint(x: x, y: y), size: size, now: now) else { continue }
                XCTAssertEqual(balloon.wrong, !balloon.good)
                points = max(0, points + (balloon.good ? 1 : -1))
                XCTAssertGreaterThanOrEqual(points, 0)
                popped += 1
            }
        }
        XCTAssertGreaterThan(popped, 0, "some balloons were on screen")
    }

    // MARK: Settings and backups

    func testSettingsDefaultLikeTheWebApp() {
        let profile = ChildProfile(name: "Lena", age: 6)
        let state = profile.playState
        XCTAssertTrue(state.gamesEnabled)
        XCTAssertTrue(profile.gamesEnabled)
        XCTAssertEqual(state.gameCost, 10)
        XCTAssertEqual(state.gamesPerDay, 3)
        XCTAssertEqual(state.gameDifficulty, .normal)
        XCTAssertEqual(state.gamesToday, 0)
        XCTAssertEqual(state.bonusGames, 0)

        // Saved like the web app: same names, same shapes, clamped.
        profile.setGameSettings(enabled: false, cost: 500, perDay: -1, difficulty: .hard)
        XCTAssertEqual(profile.webField("gamesEnabled", as: Bool.self), false)
        XCTAssertEqual(profile.webField("gameCost", as: Int.self), 100)
        XCTAssertEqual(profile.webField("gamesPerDay", as: Int.self), 0)
        XCTAssertEqual(profile.webField("gameDifficulty", as: String.self), "hard")
        XCTAssertFalse(profile.gamesEnabled)
    }

    func testGameFieldsRoundTripThroughABackup() throws {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let lena = ChildProfile(name: "Lena", age: 7)
        lena.totalStars = 40
        lena.walletStars = 40
        context.insert(lena)
        lena.setGameSettings(enabled: true, cost: 15, perDay: 0, difficulty: .easy)
        lena.playState = lena.playState.buyingTicket(.now).grantingBonusGames(2, now: .now)

        let data = try Backup.export([lena])
        let exported = try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["profiles"] as? [[String: Any]]).first
        let p = try XCTUnwrap(exported)
        XCTAssertEqual(p["gameCost"] as? Int, 15)
        XCTAssertEqual(p["gamesPerDay"] as? Int, 0)
        XCTAssertEqual(p["gameDifficulty"] as? String, "easy")
        XCTAssertEqual(p["gamesEnabled"] as? Bool, true)
        XCTAssertEqual(p["gamesToday"] as? Int, 1)
        XCTAssertEqual(p["gameDay"] as? String, Backup.dayKey(.now))
        XCTAssertEqual(p["bonusGames"] as? Int, 2)
        XCTAssertEqual(p["walletStars"] as? Int, 25)

        // Restoring replaces Lena, so remember what she had first.
        let expected = lena.playState
        guard case .success(let contents) = Backup.read(data) else { return XCTFail("backup unreadable") }
        let restored = try XCTUnwrap(try Backup.restore(contents, into: context).first)
        XCTAssertEqual(restored.playState, expected)
        XCTAssertEqual(restored.totalStars, 40)
    }
}
