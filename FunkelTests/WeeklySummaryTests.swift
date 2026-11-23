import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/weekly.test.ts (same dates and values) and the last test
/// in web/tests/providers.test.ts.
@MainActor
final class WeeklySummaryTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// A day in November 2026, 10:00 local by default.
    private func at(_ day: Int, _ hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func round(
        _ day: Int, _ subjectID: String, _ correct: Int, _ total: Int,
        effectiveAge: Double = 8, skills: [String: [Int]] = [:]
    ) -> WeeklySummary.Round {
        WeeklySummary.Round(
            date: at(day), subjectID: subjectID, languageCode: "de", correct: correct, total: total,
            starsEarned: correct, effectiveAge: effectiveAge, skills: skills
        )
    }

    func testCountsTheLastSevenDaysTodayIncludedNextToTheSevenBefore() {
        let rounds = [
            round(5, "maths", 5, 10),                       // two weeks ago: not counted
            round(10, "maths", 8, 10),                      // the week before
            round(15, "maths", 9, 10, effectiveAge: 8),
            round(15, "maths", 10, 10, effectiveAge: 8.5),
            round(17, "generalKnowledge", 6, 10),
            round(21, "maths", 7, 10, effectiveAge: 9),     // today
        ]
        let w = WeeklySummary(rounds: rounds, now: at(21, 18), calendar: calendar)
        XCTAssertEqual(w.days.first, "2026-11-15")
        XCTAssertEqual(w.days.last, "2026-11-21")
        XCTAssertEqual(w.dayRounds, [2, 0, 1, 0, 0, 0, 1])
        XCTAssertEqual(w.week, WeeklySummary.Totals(daysLearned: 3, rounds: 4, questions: 40, correct: 32, stars: 32))
        XCTAssertEqual(w.previous, WeeklySummary.Totals(daysLearned: 1, rounds: 1, questions: 10, correct: 8, stars: 8))
        XCTAssertEqual(w.subjects.count, 2)
        let maths = w.subjects[0]
        XCTAssertEqual(maths.subjectID, "maths")
        XCTAssertEqual(maths.rounds, 3)
        XCTAssertEqual(maths.questions, 30)
        XCTAssertEqual(maths.correct, 26)
        XCTAssertEqual(maths.levelStart, 8)
        XCTAssertEqual(maths.levelEnd, 9)
        XCTAssertEqual(w.subjects[1].subjectID, "generalKnowledge")
        XCTAssertEqual(w.subjects[1].rounds, 1)
    }

    func testNamesWhatWentWellAndWhatToPractiseOnceThereAreEnoughAnswers() {
        let rounds = [
            round(20, "maths", 8, 10, skills: ["addition": [5, 5], "division": [1, 4], "subtraction": [1, 1]]),
            round(21, "generalKnowledge", 9, 10, skills: ["animals": [4, 4], "history": [2, 3]]),
            round(21, "generalKnowledge", 9, 10, skills: ["history": [1, 2]]),
            round(21, "vocabulary", 10, 10), // older rounds without skills still count in the totals
        ]
        let w = WeeklySummary(rounds: rounds, now: at(21, 18), calendar: calendar)
        XCTAssertEqual(w.strong.map(\.skill), ["addition", "animals"])
        XCTAssertEqual(w.practice.map(\.skill), ["division", "history"])
        XCTAssertEqual(w.practice.map(\.correct), [1, 3])
        XCTAssertEqual(w.practice.map(\.asked), [4, 5])
        XCTAssertEqual(w.week.rounds, 4)
    }

    func testIsEmptyForAChildWhoHasntLearnedThisWeek() {
        let w = WeeklySummary(rounds: [round(1, "maths", 5, 10)], now: at(21), calendar: calendar)
        XCTAssertEqual(w.week.rounds, 0)
        XCTAssertTrue(w.dayRounds.allSatisfy { $0 == 0 })
        XCTAssertEqual(w.strong, [])
    }

    func testTalliesARoundsAnswersPerKindAndKeepsThemInTheHistory() throws {
        XCTAssertEqual(
            WeeklySummary.skillTally(["addition", "addition", nil, "division"], [true, false, true, true]),
            ["addition": [1, 2], "division": [1, 1]]
        )

        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let recorder = ProgressRecorder(context: context)

        let emil = ChildProfile(name: "Emil", age: 7)
        context.insert(emil)
        var outcome = RoundOutcome(subjectID: "maths", languageCode: "de", correct: 2, total: 3, correctContentIDs: [], effectiveAge: 7)
        outcome.skills = ["addition": [2, 3]]
        recorder.record(outcome, for: emil, at: at(21), calendar: calendar)
        XCTAssertEqual(emil.rounds.first?.skillStats, ["addition": [2, 3]])

        let ida = ChildProfile(name: "Ida", age: 7)
        context.insert(ida)
        recorder.record(
            RoundOutcome(subjectID: "maths", languageCode: "de", correct: 1, total: 1, correctContentIDs: [], effectiveAge: 7),
            for: ida, at: at(21), calendar: calendar
        )
        XCTAssertEqual(ida.rounds.first?.skillStats, [:])

        // And the overview reads them from the saved history.
        let w = WeeklySummary(profile: emil, now: at(21, 18), calendar: calendar)
        XCTAssertEqual(w.week.rounds, 1)
        XCTAssertEqual(w.strong, [])
        XCTAssertEqual(w.practice, [], "3 answers are too few to count")
    }

    // MARK: Kinds of questions (mirrors the last test in web/tests/providers.test.ts)

    func testEveryQuestionCarriesItsOperationWordExerciseOrCategory() throws {
        let library = ContentLibrary.bundled()
        let language = try XCTUnwrap(library.language(code: "de"))
        var rng = SeededGenerator(seed: 7)
        for id in ["maths", "vocabulary", "generalKnowledge", "topic-pilze"] {
            let subject = try XCTUnwrap(language.subject(id: id), id)
            let provider = try XCTUnwrap(try QuestionProviderFactory.provider(for: subject, content: library), id)
            for age in [6, 8, 10] {
                let questions = provider.makeQuestions(
                    count: 10, difficulty: DifficultyScale.difficulty(forAge: age), recentlyCorrect: [], using: &rng
                )
                XCTAssertFalse(questions.isEmpty, "\(id) at \(age)")
                for q in questions {
                    XCTAssertFalse((q.skill ?? "").isEmpty, "\(id) at \(age): \(q.prompt)")
                }
            }
        }
    }

    func testMathsAndVocabularyKindsAreTheWebIds() throws {
        // The catalog has "skill.<id>" for these, shared with the web app.
        XCTAssertEqual(MathsOperation.allCases.map(\.rawValue), [
            "counting", "numberRecognition", "addition", "subtraction", "multiplication", "division", "wordProblem", "missingNumber",
        ])
        XCTAssertEqual(VocabularyQuestionType.allCases.map(\.rawValue), [
            "pictureToWord", "wordToPicture", "meaning", "spelling", "opposite", "synonym",
        ])
    }
}
