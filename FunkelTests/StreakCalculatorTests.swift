import XCTest
@testable import Funkel

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func day(_ d: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: hour))!
    }

    func testFirstRoundStartsStreak() {
        let r = StreakCalculator.update(current: 0, longest: 0, lastPlayedDay: nil, playedAt: day(1), calendar: calendar)
        XCTAssertEqual(r.current, 1)
        XCTAssertEqual(r.longest, 1)
    }

    func testSameDayDoesNotIncrement() {
        let r = StreakCalculator.update(current: 3, longest: 5, lastPlayedDay: day(2, hour: 8), playedAt: day(2, hour: 19), calendar: calendar)
        XCTAssertEqual(r.current, 3)
        XCTAssertEqual(r.longest, 5)
    }

    func testConsecutiveDayIncrements() {
        let r = StreakCalculator.update(current: 3, longest: 3, lastPlayedDay: day(2, hour: 23), playedAt: day(3, hour: 7), calendar: calendar)
        XCTAssertEqual(r.current, 4)
        XCTAssertEqual(r.longest, 4)
    }

    func testGapResetsButKeepsLongest() {
        let r = StreakCalculator.update(current: 6, longest: 6, lastPlayedDay: day(2), playedAt: day(5), calendar: calendar)
        XCTAssertEqual(r.current, 1)
        XCTAssertEqual(r.longest, 6)
    }

    func testDisplayedStreakLapsesAfterAMissedDay() {
        XCTAssertEqual(StreakCalculator.displayedStreak(current: 4, lastPlayedDay: day(2), now: day(3), calendar: calendar), 4)
        XCTAssertEqual(StreakCalculator.displayedStreak(current: 4, lastPlayedDay: day(2), now: day(4), calendar: calendar), 0)
    }
}
