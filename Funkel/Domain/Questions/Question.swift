import Foundation

/// One screen of a round. Built at runtime by a `QuestionProvider`; never persisted.
/// All text is already in the learning language.
struct Question: Identifiable, Equatable, Sendable {
    let id: UUID
    let subjectID: String
    /// Optional content id, used to avoid repeats across rounds.
    let contentID: String?
    let prompt: String
    /// A fill-the-gap sentence containing `___`, shown below the prompt.
    let sentence: String?
    let visual: QuestionVisual?
    let format: QuestionFormat
    /// Shown gently after a wrong answer, e.g. "Wale sind Säugetiere."
    let explanation: String?
    /// Overrides what read-aloud says, e.g. "3 plus 4" instead of "3 + 4".
    let spoken: String?

    init(
        id: UUID = UUID(),
        subjectID: String,
        contentID: String? = nil,
        prompt: String,
        sentence: String? = nil,
        visual: QuestionVisual? = nil,
        format: QuestionFormat,
        explanation: String? = nil,
        spoken: String? = nil
    ) {
        self.id = id
        self.subjectID = subjectID
        self.contentID = contentID
        self.prompt = prompt
        self.sentence = sentence
        self.visual = visual
        self.format = format
        self.explanation = explanation
        self.spoken = spoken
    }

    /// Text handed to the speech synthesiser.
    var spokenText: String {
        if let spoken { return spoken }
        guard let sentence else { return prompt }
        return prompt + " " + sentence.replacingOccurrences(of: "___", with: "…")
    }
}

enum QuestionVisual: Equatable, Sendable {
    /// A single large emoji picture.
    case emoji(String)
    /// `count` copies of `symbol` laid out for counting.
    case countable(symbol: String, count: Int)
    /// A large equation such as "7 + 5 = ?".
    case equation(String)
}

enum QuestionFormat: Equatable, Sendable {
    case multipleChoice(options: [AnswerOption], correctIndex: Int)
    case numberEntry(answer: Int)
    /// Tap tiles in order: letters for spelling, words for sentence building.
    case buildSequence(tiles: [String], answer: [String])
}

struct AnswerOption: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
    /// When set and pictures are enabled, the option shows the emoji large
    /// with `text` as its accessibility label.
    let emoji: String?

    init(id: Int, text: String, emoji: String? = nil) {
        self.id = id
        self.text = text
        self.emoji = emoji
    }
}

extension QuestionFormat {
    /// Human-readable correct answer, for the gentle "the answer was …" reveal.
    var correctAnswerText: String {
        switch self {
        case let .multipleChoice(options, correctIndex):
            return options.indices.contains(correctIndex) ? options[correctIndex].text : ""
        case let .numberEntry(answer):
            return String(answer)
        case let .buildSequence(tiles, answer):
            let joiner = tiles.allSatisfy { $0.count == 1 } ? "" : " "
            return answer.joined(separator: joiner)
        }
    }
}
