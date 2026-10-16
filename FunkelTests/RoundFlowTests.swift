import SwiftData
import XCTest
@testable import Funkel

@MainActor
final class RoundFlowTests: XCTestCase {

    private let subject = SubjectDescriptor(
        id: "maths", languageCode: "de", provider: .maths, file: "maths.json",
        title: "Mathe", icon: "plus", colorHex: "#E8702A"
    )

    private func choiceQuestion(correct: Int = 1) -> Question {
        Question(
            subjectID: "maths",
            prompt: "Wie viel ist 1 + 1?",
            format: .multipleChoice(options: [AnswerOption(id: 0, text: "1"), AnswerOption(id: 1, text: "2"), AnswerOption(id: 2, text: "3")], correctIndex: correct)
        )
    }

    // MARK: RoundViewModel

    func testMultipleChoiceFlow() {
        let vm = RoundViewModel(subject: subject, questions: [choiceQuestion(), choiceQuestion()], difficulty: DifficultyScale.difficulty(forAge: 6))
        XCTAssertEqual(vm.phase, .answering)

        vm.choose(optionIndex: 1)
        XCTAssertEqual(vm.phase, .feedback(isCorrect: true))
        vm.choose(optionIndex: 0)
        XCTAssertEqual(vm.results, [true], "answers during feedback are ignored")

        vm.next()
        XCTAssertEqual(vm.phase, .answering)
        XCTAssertNil(vm.selectedOptionIndex)

        vm.choose(optionIndex: 2)
        XCTAssertEqual(vm.phase, .feedback(isCorrect: false))
        vm.next()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(vm.outcome.correct, 1)
        XCTAssertEqual(vm.outcome.total, 2)
    }

    func testNumberPadInput() {
        let q = Question(subjectID: "maths", prompt: "?", format: .numberEntry(answer: 42))
        let vm = RoundViewModel(subject: subject, questions: [q], difficulty: DifficultyScale.difficulty(forAge: 9))
        XCTAssertFalse(vm.canSubmitNumber)

        vm.appendDigit(0)
        vm.appendDigit(4)
        XCTAssertEqual(vm.numberInput, "4", "a leading zero is replaced")
        vm.appendDigit(2)
        vm.appendDigit(2)
        vm.appendDigit(2)
        vm.appendDigit(2)
        XCTAssertEqual(vm.numberInput, "4222", "input is capped at answer length + 2")
        vm.deleteDigit()
        vm.deleteDigit()
        vm.toggleSign()
        XCTAssertEqual(vm.numberInput, "42", "no negative numbers below age 12")

        vm.submitNumber()
        XCTAssertEqual(vm.phase, .feedback(isCorrect: true))
    }

    func testNegativeInputForOlderChildren() {
        let q = Question(subjectID: "maths", prompt: "?", format: .numberEntry(answer: -7))
        let vm = RoundViewModel(subject: subject, questions: [q], difficulty: DifficultyScale.difficulty(forAge: 13))
        vm.appendDigit(7)
        vm.toggleSign()
        XCTAssertEqual(vm.numberInput, "-7")
        vm.submitNumber()
        XCTAssertEqual(vm.phase, .feedback(isCorrect: true))
    }

    // MARK: ProgressRecorder

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testRecordingUpdatesStarsStreakProgressAndHistory() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Lena", age: 7)
        context.insert(profile)
        let recorder = ProgressRecorder(context: context)
        let outcome = RoundOutcome(subjectID: "maths", languageCode: "de", correct: 10, total: 10, correctContentIDs: ["a"], effectiveAge: 7)

        let day1 = Date(timeIntervalSince1970: 1_780_000_000)
        let first = recorder.record(outcome, for: profile, at: day1)
        XCTAssertEqual(first.starsEarned, 10)
        XCTAssertEqual(first.streak, 1)
        XCTAssertTrue(first.streakGrew)
        XCTAssertEqual(profile.totalStars, 10)
        XCTAssertEqual(profile.difficultyAdjustment, 0.15, accuracy: 0.0001)

        let second = recorder.record(outcome, for: profile, at: day1.addingTimeInterval(86_400))
        XCTAssertEqual(second.streak, 2)

        let progress = try XCTUnwrap(profile.subjectProgress(for: "maths", language: "de"))
        XCTAssertEqual(progress.roundsPlayed, 2)
        XCTAssertEqual(progress.correctAnswers, 20)
        XCTAssertEqual(progress.recentCorrectContentIDs, ["a", "a"])
        XCTAssertEqual(profile.progress.count, 1, "progress is reused, not duplicated")
        XCTAssertEqual(profile.rounds.count, 2)
    }

    func testChangingAgeResetsAdjustment() {
        let profile = ChildProfile(name: "Emil", age: 9)
        profile.difficultyAdjustment = 0.6
        profile.gentleTimerEnabled = true
        profile.setAge(8)
        XCTAssertEqual(profile.age, 8)
        XCTAssertEqual(profile.difficultyAdjustment, 0)
        XCTAssertFalse(profile.gentleTimerEnabled, "timer is only offered from age 9")
    }
}
