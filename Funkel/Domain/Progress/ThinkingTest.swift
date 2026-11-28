import Foundation
import SwiftData

/// The Denk-Test: 24 Denken puzzles that get harder, from two years below the
/// child's age to well above it (two per half year). It ends early after four
/// wrong answers in a row, like real reasoning tests. The score is the number
/// right and a "Denk-Niveau": the age the puzzles he still solves are made for.
/// Compared only with the child's own earlier tests: there is no IQ and no
/// comparison with other children. Mirrors web/src/domain/thinkingTest.ts.
enum ThinkingTest {
    static let steps = 12
    static let perStep = 2
    static let questionCount = steps * perStep
    /// Each step is half a year harder; the first one is two years below the child's age.
    static let stepYears = 0.5
    static let startBelow = 2.0
    /// Four wrong in a row: the puzzles are too hard now, so the test ends kindly.
    static let stopAfterWrong = 4
    /// One test a week, so the score shows a real change and isn't just practice.
    static let everyDays = 7
    static let historyLimit = 100

    /// One finished test, stored in the web field `thinkingTests` in the web app's shape.
    struct Result: Codable, Equatable, Sendable {
        /// ISO date, like JavaScript's `toISOString()`.
        var date: String
        /// The child's age when taking it.
        var age: Int
        var points: Int
        var total: Int
        /// The age the puzzles he still solved are made for, in half years.
        var levelAge: Double
    }

    /// A finished test for the summary, with the test before it for comparison.
    struct Finished: Equatable {
        let result: Result
        let stars: Int
        let previous: Result?
    }

    private static var minAge: Double { Double(DifficultyTuning.minAge) }
    private static var maxAge: Double { Double(DifficultyTuning.maxAge) }

    static func startAge(age: Int) -> Double {
        (Double(age) - startBelow).clamped(to: minAge...maxAge)
    }

    /// The difficulty (effective age) of each step.
    static func stepAges(age: Int) -> [Double] {
        let start = startAge(age: age)
        return (0..<steps).map { min(maxAge, start + Double($0) * stepYears) }
    }

    /// Two puzzles per step, easiest first.
    static func makeTest<R: RandomNumberGenerator>(provider: any QuestionProvider, age: Int, using rng: inout R) -> [Question] {
        var questions: [Question] = []
        for stepAge in stepAges(age: age) {
            questions += provider.makeQuestions(
                count: perStep,
                difficulty: DifficultyScale.difficulty(effectiveAge: stepAge),
                recentlyCorrect: [],
                using: &rng
            )
        }
        return questions
    }

    static func makeTest(provider: any QuestionProvider, age: Int) -> [Question] {
        var rng = SystemRandomNumberGenerator()
        return makeTest(provider: provider, age: age, using: &rng)
    }

    /// Stop once the last four answers were all wrong.
    static func shouldStop(_ results: [Bool]) -> Bool {
        results.count >= stopAfterWrong && results.suffix(stopAfterWrong).allSatisfy { !$0 }
    }

    /// Each point is a quarter year above the half year before the first step, in
    /// half years and within 4–14: 0 points at age 7 → 4½, 10 points → 7, 24 → 10½.
    static func levelAge(age: Int, points: Int) -> Double {
        let raw = startAge(age: age) - stepYears + Double(points) * stepYears / Double(perStep)
        return ((raw * 2).rounded(.down) / 2).clamped(to: minAge...maxAge)
    }

    /// The day the next test can be taken, "YYYY-MM-DD" (today if never).
    static func nextTestDay(_ tests: [Result], now: Date = .now, calendar: Calendar = .current) -> String {
        guard let last = tests.last, let taken = Backup.date(fromISO: last.date),
              let next = calendar.date(byAdding: .day, value: everyDays, to: taken)
        else { return Backup.dayKey(now, calendar: calendar) }
        return Backup.dayKey(next, calendar: calendar)
    }

    static func canTakeTest(_ tests: [Result], now: Date = .now, calendar: Calendar = .current) -> Bool {
        nextTestDay(tests, now: now, calendar: calendar) <= Backup.dayKey(now, calendar: calendar)
    }

    /// Days until the next test (0 = now).
    static func daysUntilTest(_ tests: [Result], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let next = Backup.date(fromDayKey: nextTestDay(tests, now: now, calendar: calendar), calendar: calendar) else { return 0 }
        let today = calendar.startOfDay(for: now)
        return max(0, Int((next.timeIntervalSince(today) / 86_400).rounded()))
    }
}

extension ChildProfile {
    /// Denk-Test results, oldest first (web field `thinkingTests`).
    var thinkingTests: [ThinkingTest.Result] {
        get { webField("thinkingTests") ?? [] }
        set { setWebField("thinkingTests", newValue) }
    }
}

extension ProgressRecorder {
    /// A finished Denk-Test: kept in the history, stars (one per two points)
    /// into the total and the wallet, the streak, and a round in the history
    /// (subject Denken) for the weekly overview. The Denken subject's level
    /// isn't changed.
    @discardableResult
    func recordThinkingTest(
        points: Int,
        total: Int = ThinkingTest.questionCount,
        skills: [String: [Int]],
        subjectID: String,
        languageCode: String,
        for profile: ChildProfile,
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> (result: ThinkingTest.Result, stars: Int) {
        let result = ThinkingTest.Result(
            date: Backup.isoString(now),
            age: profile.age,
            points: points,
            total: total,
            levelAge: ThinkingTest.levelAge(age: profile.age, points: points)
        )
        let stars = (points + 1) / 2
        profile.totalStars += stars
        profile.walletStars += stars

        let streak = StreakCalculator.update(
            current: profile.currentStreak,
            longest: profile.longestStreak,
            lastPlayedDay: profile.lastPlayedDay,
            playedAt: now,
            calendar: calendar
        )
        profile.currentStreak = streak.current
        profile.longestStreak = streak.longest
        profile.lastPlayedDay = streak.lastPlayedDay

        profile.thinkingTests = Array((profile.thinkingTests + [result]).suffix(ThinkingTest.historyLimit))

        let record = RoundRecord(
            date: now,
            subjectID: subjectID,
            languageCode: languageCode,
            correct: points,
            total: total,
            starsEarned: stars,
            effectiveAge: result.levelAge,
            skillStats: skills
        )
        context.insert(record)
        profile.rounds.append(record)

        try? context.save()
        return (result, stars)
    }
}
