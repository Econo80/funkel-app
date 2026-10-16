import Foundation
import Observation

/// Drives one round: current question, answer checking, feedback and score.
/// Knows nothing about persistence; the view hands the finished `RoundOutcome`
/// to `ProgressRecorder`.
@MainActor
@Observable
final class RoundViewModel {

    enum Phase: Equatable {
        case answering
        case feedback(isCorrect: Bool)
        case finished
    }

    let subject: SubjectDescriptor
    let questions: [Question]
    let difficulty: Difficulty

    private(set) var index = 0
    private(set) var phase: Phase = .answering
    private(set) var selectedOptionIndex: Int?
    private(set) var numberInput = ""
    private(set) var results: [Bool] = []
    private(set) var correctContentIDs: [String] = []

    init(subject: SubjectDescriptor, questions: [Question], difficulty: Difficulty) {
        self.subject = subject
        self.questions = questions
        self.difficulty = difficulty
        if questions.isEmpty { phase = .finished }
    }

    // MARK: Derived state

    var current: Question? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var correctCount: Int { results.filter { $0 }.count }
    var questionNumber: Int { min(index + 1, questions.count) }
    var isLastQuestion: Bool { index >= questions.count - 1 }

    /// Maximum digits accepted on the number pad for the current question.
    var maxInputLength: Int {
        guard case let .numberEntry(answer)? = current?.format else { return 0 }
        return String(abs(answer)).count + 2
    }

    // MARK: Answering

    func choose(optionIndex: Int) {
        guard phase == .answering, case let .multipleChoice(options, correctIndex)? = current?.format,
              options.indices.contains(optionIndex) else { return }
        selectedOptionIndex = optionIndex
        record(isCorrect: optionIndex == correctIndex)
    }

    func appendDigit(_ digit: Int) {
        guard phase == .answering, (0...9).contains(digit) else { return }
        let digits = numberInput.filter(\.isNumber)
        guard digits.count < maxInputLength else { return }
        if digits == "0" {
            numberInput = numberInput.replacingOccurrences(of: "0", with: String(digit))
        } else {
            numberInput.append(String(digit))
        }
    }

    func deleteDigit() {
        guard phase == .answering, !numberInput.isEmpty else { return }
        numberInput.removeLast()
        if numberInput == "-" { numberInput = "" }
    }

    func toggleSign() {
        guard phase == .answering, difficulty.maths.allowsNegativeResults else { return }
        if numberInput.hasPrefix("-") {
            numberInput.removeFirst()
        } else {
            numberInput = "-" + numberInput
        }
    }

    var canSubmitNumber: Bool {
        phase == .answering && Int(numberInput) != nil
    }

    func submitNumber() {
        guard canSubmitNumber, case let .numberEntry(answer)? = current?.format, let value = Int(numberInput) else { return }
        record(isCorrect: value == answer)
    }

    /// From feedback to the next question, or to the end of the round.
    func next() {
        guard case .feedback = phase else { return }
        if isLastQuestion {
            phase = .finished
        } else {
            index += 1
            selectedOptionIndex = nil
            numberInput = ""
            phase = .answering
        }
    }

    private func record(isCorrect: Bool) {
        results.append(isCorrect)
        if isCorrect, let id = current?.contentID {
            correctContentIDs.append(id)
        }
        phase = .feedback(isCorrect: isCorrect)
    }

    // MARK: Outcome

    var outcome: RoundOutcome {
        RoundOutcome(
            subjectID: subject.id,
            languageCode: subject.languageCode,
            correct: correctCount,
            total: results.count,
            correctContentIDs: correctContentIDs,
            effectiveAge: difficulty.effectiveAge
        )
    }
}
