import Foundation

// Schemas for the JSON files under `Content/<lang>/`.
// `scripts/validate_content.py` checks the same rules outside Xcode.

// MARK: - strings.json

/// Learning-language phrasing templates with `{placeholder}` slots.
/// Lives in content (not the String Catalog) so it follows the learning
/// language, not the device language (PLAN.md §6).
struct Phrasing: Decodable, Sendable {
    let templates: [String: String]

    init(templates: [String: String]) {
        self.templates = templates
    }

    init(from decoder: Decoder) throws {
        templates = try decoder.singleValueContainer().decode([String: String].self)
    }

    func text(_ key: String, _ values: [String: String] = [:]) -> String {
        guard var result = templates[key] else {
            assertionFailure("Missing phrasing key '\(key)'")
            return key
        }
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return result
    }
}

// MARK: - maths.json

struct MathsContent: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let singular: String
        let plural: String
        let emoji: String
    }

    struct WordProblem: Decodable, Sendable {
        /// "addition" | "subtraction" | "multiplication" | "division"
        let operation: MathsOperation
        let minAge: Int
        /// Placeholders: {name}, {a}, {b}, {item}, {items}
        let template: String
    }

    let names: [String]
    let items: [Item]
    let wordProblems: [WordProblem]
}

// MARK: - vocabulary.json (provider: wordList)

struct WordList: Decodable, Sendable {
    struct Entry: Decodable, Sendable, Identifiable {
        var id: String { word }
        let word: String
        /// Grammatical article where the language has one ("der", "die", "das").
        let article: String?
        let emoji: String?
        let definition: String?
        let synonyms: [String]?
        let antonyms: [String]?
        let category: String?
        let minAge: Int
        let maxAge: Int?
    }

    let words: [Entry]
}

// MARK: - generalknowledge.json, grammar.json, … (provider: questionBank)

struct QuestionBank: Decodable, Sendable {
    enum Format: String, Decodable, Sendable {
        case multipleChoice
        case buildSequence
    }

    struct Item: Decodable, Sendable, Identifiable {
        let id: String
        let category: String?
        let minAge: Int
        let maxAge: Int?
        let format: Format
        let prompt: String
        /// Optional fill-the-gap sentence containing `___`.
        let sentence: String?
        let emoji: String?
        let explanation: String?

        // multipleChoice
        /// All options including the correct one. Trimmed to the age's option count at runtime.
        let options: [String]?
        let correct: String?

        // buildSequence
        /// The tiles in the correct order.
        let answer: [String]?
        /// Extra wrong tiles mixed in for older children.
        let distractors: [String]?
    }

    let questions: [Item]
}
