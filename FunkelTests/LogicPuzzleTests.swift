import SwiftData
import XCTest
@testable import Funkel

private func shapeOf(_ picture: String) -> Int {
    LogicPuzzleGenerator.shapes.firstIndex { $0.contains(picture) } ?? -1
}

private func colourOf(_ picture: String) -> Int {
    let shape = shapeOf(picture)
    guard shape >= 0 else { return -1 }
    return LogicPuzzleGenerator.shapes[shape].firstIndex(of: picture) ?? -1
}

/// Mirrors web/tests/logic.test.ts.
@MainActor
final class LogicPuzzleTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func provider() throws -> LogicPuzzleGenerator {
        let library = ContentLibrary.bundled()
        let subject = try XCTUnwrap(library.language(code: "de")?.subject(id: "logic"))
        return try XCTUnwrap(QuestionProviderFactory.provider(for: subject, content: library) as? LogicPuzzleGenerator)
    }

    // MARK: Denken puzzles

    func testFairAtEveryAgeWithOneRightAnswerAndKindsUnlockedByAge() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 3)
        for age in [4, 5, 6, 7, 8, 9, 10, 11, 12, 14] {
            let d = DifficultyScale.difficulty(forAge: age)
            let questions = p.makeQuestions(count: 30, difficulty: d, recentlyCorrect: [], using: &rng)
            XCTAssertEqual(questions.count, 30, "age \(age)")
            let kinds = Set(questions.compactMap(\.skill))
            if Double(age) < 5.5 {
                XCTAssertEqual(kinds, ["oddOneOut", "pattern"], "age \(age)")
            }
            if age >= 9 {
                XCTAssertTrue(kinds.contains("matrix") && kinds.contains("numberSequence"), "age \(age)")
            }
            for q in questions {
                switch q.format {
                case let .multipleChoice(options, correctIndex):
                    let texts = options.map(\.text)
                    XCTAssertEqual(Set(texts).count, texts.count, q.prompt)
                    XCTAssertEqual(texts.count, q.skill == "oddOneOut" ? 4 : d.answerOptionCount, "age \(age): \(q.prompt)")
                    XCTAssertTrue(options.indices.contains(correctIndex), q.prompt)
                case .numberEntry:
                    XCTAssertEqual(q.skill, "numberSequence")
                case .buildSequence:
                    XCTFail("Denken has no tiles to build: \(q.prompt)")
                }
                if case let .tiles(items, _)? = q.visual {
                    XCTAssertEqual(items.filter { $0 == LogicPuzzleGenerator.missing }.count, 1, q.prompt)
                }
            }
        }
    }

    func testFieldsWhereTheAnswerFollowsBothRules() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 9)
        for age in [7, 9] {
            let matrices = p.makeQuestions(count: 40, difficulty: DifficultyScale.difficulty(forAge: age), recentlyCorrect: [], using: &rng)
                .filter { $0.skill == "matrix" }
            XCTAssertGreaterThan(matrices.count, 3, "age \(age)")
            for q in matrices {
                guard case let .tiles(items, columns)? = q.visual, case let .multipleChoice(options, correctIndex) = q.format else {
                    XCTFail("matrix shape")
                    continue
                }
                XCTAssertEqual(columns, 3)
                let answer = options[correctIndex].text
                let cells = items.map { $0 == LogicPuzzleGenerator.missing ? answer : $0 }
                XCTAssertEqual(cells.count, 9)
                for r in 0..<3 {
                    let row = Array(cells[(r * 3)..<(r * 3 + 3)])
                    let column = [cells[r], cells[r + 3], cells[r + 6]]
                    if age >= 8 {
                        // Every row and column has each shape and each colour once.
                        for line in [row, column] {
                            XCTAssertEqual(Set(line.map(shapeOf)).count, 3, line.joined())
                            XCTAssertEqual(Set(line.map(colourOf)).count, 3, line.joined())
                        }
                    } else {
                        XCTAssertEqual(Set(row.map(shapeOf)).count, 1, row.joined())
                        XCTAssertEqual(Set(column.map(colourOf)).count, 1, column.joined())
                    }
                }
            }
        }
    }

    func testNumberSequencesWhoseAnswerFollowsTheRule() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 5)
        let sequences = p.makeQuestions(count: 60, difficulty: DifficultyScale.difficulty(forAge: 7), recentlyCorrect: [], using: &rng)
            .filter { $0.skill == "numberSequence" }
        XCTAssertFalse(sequences.isEmpty)
        for q in sequences {
            guard case let .equation(text)? = q.visual, case let .multipleChoice(options, correctIndex) = q.format else { continue }
            let answer = try XCTUnwrap(Int(options[correctIndex].text))
            let values = text.components(separatedBy: ", ").map { $0 == "?" ? answer : (Int($0) ?? -1) }
            let steps = zip(values.dropFirst(), values).map { $0 - $1 }
            XCTAssertEqual(Set(steps).count, 1, text) // under 8.5: always the same step
        }
    }

    // MARK: Denk-Test

    func testGoesFromTwoYearsBelowTheAgeUpwardsTwoPuzzlesPerHalfYear() throws {
        XCTAssertEqual(ThinkingTest.stepAges(age: 7), [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5])
        XCTAssertEqual(ThinkingTest.stepAges(age: 4).first, 4)
        XCTAssertEqual(ThinkingTest.stepAges(age: 14).max(), 14)
        let p = try provider()
        var rng = SeededGenerator(seed: 1)
        let test = ThinkingTest.makeTest(provider: p, age: 7, using: &rng)
        XCTAssertEqual(test.count, ThinkingTest.questionCount)
        // The first step is too young for matrices.
        XCTAssertFalse(test.prefix(2).contains { $0.skill == "matrix" })
    }

    func testStopsAfterFourWrongInARowAndTurnsPointsIntoADenkNiveau() {
        XCTAssertFalse(ThinkingTest.shouldStop([true, false, false, false]))
        XCTAssertTrue(ThinkingTest.shouldStop([true, false, false, false, false]))
        XCTAssertEqual(ThinkingTest.levelAge(age: 7, points: 0), 4.5)
        XCTAssertEqual(ThinkingTest.levelAge(age: 7, points: 10), 7)
        XCTAssertEqual(ThinkingTest.levelAge(age: 7, points: 12), 7.5)
        XCTAssertEqual(ThinkingTest.levelAge(age: 7, points: 24), 10.5)
        XCTAssertEqual(ThinkingTest.levelAge(age: 4, points: 0), 4)
        XCTAssertEqual(ThinkingTest.levelAge(age: 13, points: 24), 14)
    }

    /// In the round: after the fourth wrong answer in a row the rest is dropped and the test ends.
    func testTheRoundEndsAfterFourWrongInARow() {
        let subject = SubjectDescriptor(id: "logic", languageCode: "de", provider: .logic, file: "logic.json", title: "Denken", icon: "a", colorHex: "#7B61D9")
        let options = [AnswerOption(id: 0, text: "🍎"), AnswerOption(id: 1, text: "🚗")]
        let questions = (0..<8).map { _ in
            Question(subjectID: "logic", prompt: "?", format: .multipleChoice(options: options, correctIndex: 0), skill: "pattern")
        }
        let vm = RoundViewModel(subject: subject, questions: questions, difficulty: DifficultyScale.difficulty(forAge: 7), isTest: true)
        vm.choose(optionIndex: 0)
        vm.next()
        for _ in 0..<3 {
            vm.choose(optionIndex: 1)
            vm.next()
        }
        XCTAssertEqual(vm.questions.count, 8, "three wrong in a row go on")
        vm.choose(optionIndex: 1)
        XCTAssertEqual(vm.questions.count, 5)
        vm.next()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(vm.outcome.correct, 1)
        XCTAssertEqual(vm.outcome.skills, ["pattern": [1, 5]])
    }

    func testIsKeptPaysStarsCountsInTheWeekAndCanBeTakenAgainAfterSevenDays() throws {
        let context = try makeContext()
        let now = at(2026, 11, 28, 10)
        let profile = ChildProfile(name: "Emil", age: 7)
        context.insert(profile)
        profile.totalStars = 5
        profile.walletStars = 5
        XCTAssertTrue(ThinkingTest.canTakeTest(profile.thinkingTests, now: now, calendar: calendar))

        let recorded = ProgressRecorder(context: context).recordThinkingTest(
            points: 15, total: 24, skills: ["matrix": [3, 5]], subjectID: "logic", languageCode: "de",
            for: profile, at: now, calendar: calendar
        )
        XCTAssertEqual(recorded.result.age, 7)
        XCTAssertEqual(recorded.result.points, 15)
        XCTAssertEqual(recorded.result.total, 24)
        XCTAssertEqual(recorded.result.levelAge, 8)
        XCTAssertEqual(recorded.stars, 8)
        XCTAssertEqual(profile.totalStars, 13)
        XCTAssertEqual(profile.walletStars, 13)
        XCTAssertEqual(profile.currentStreak, 1)
        XCTAssertEqual(profile.thinkingTests, [recorded.result])
        XCTAssertTrue(profile.progress.isEmpty, "the Denken level isn't changed")
        XCTAssertEqual(profile.rounds.first?.skillStats, ["matrix": [3, 5]])

        let week = WeeklySummary(profile: profile, now: now, calendar: calendar)
        let first = try XCTUnwrap(week.subjects.first)
        XCTAssertEqual(first.subjectID, "logic")
        XCTAssertEqual(first.rounds, 1)
        XCTAssertEqual(first.correct, 15)
        XCTAssertEqual(first.questions, 24)

        let tests = profile.thinkingTests
        XCTAssertFalse(ThinkingTest.canTakeTest(tests, now: at(2026, 12, 4, 10), calendar: calendar))
        XCTAssertEqual(ThinkingTest.daysUntilTest(tests, now: at(2026, 12, 4, 10), calendar: calendar), 1)
        XCTAssertTrue(ThinkingTest.canTakeTest(tests, now: at(2026, 12, 5, 8), calendar: calendar))

        // Stored in the web app's field and shape, and cleared with the progress.
        let stored = try XCTUnwrap(BackupExtras.decode(profile.backupExtras)["thinkingTests"] as? [[String: Any]])
        XCTAssertEqual(stored.first?["points"] as? Int, 15)
        XCTAssertEqual(stored.first?["levelAge"] as? Double, 8)
        ProfileMaintenance.resetProgress(of: profile, in: context)
        XCTAssertTrue(profile.thinkingTests.isEmpty)
    }
}
