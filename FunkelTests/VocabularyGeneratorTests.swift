import XCTest
@testable import Funkel

final class VocabularyGeneratorTests: XCTestCase {

    private func generator() throws -> VocabularyQuestionGenerator {
        let library = ContentLibrary.bundled()
        let subject = try XCTUnwrap(library.language(code: "de")?.subject(id: "vocabulary"))
        return try XCTUnwrap(QuestionProviderFactory.provider(for: subject, content: library) as? VocabularyQuestionGenerator)
    }

    private func words(_ g: VocabularyQuestionGenerator) -> [String: WordList.Entry] {
        Dictionary(uniqueKeysWithValues: g.words.map { ($0.word, $0) })
    }

    func testFullRoundsAtEveryAge() throws {
        let g = try generator()
        var rng = SeededGenerator(seed: 1)
        for age in DifficultyTuning.ageRange {
            let d = DifficultyScale.difficulty(forAge: age)
            let questions = g.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng)
            XCTAssertEqual(questions.count, 10, "age \(age)")
            XCTAssertEqual(Set(questions.compactMap(\.contentID)).count, 10, "no repeated words within a round at age \(age)")
            for q in questions {
                XCTAssertFalse(q.prompt.contains("{"), q.prompt)
                switch q.format {
                case let .multipleChoice(options, index):
                    XCTAssertTrue(options.indices.contains(index))
                    XCTAssertGreaterThanOrEqual(options.count, 2)
                    XCTAssertLessThanOrEqual(options.count, d.answerOptionCount)
                    XCTAssertEqual(Set(options.map(\.text)).count, options.count, "duplicate options \(options.map(\.text))")
                case let .buildSequence(tiles, answer):
                    XCTAssertLessThanOrEqual(answer.count, d.vocabulary.spellingMaxLength)
                    XCTAssertEqual(tiles.count, answer.count + d.vocabulary.spellingDistractorLetters)
                    var pool = tiles
                    for letter in answer {
                        let i = try XCTUnwrap(pool.firstIndex(of: letter), "tiles must contain every letter of \(answer)")
                        pool.remove(at: i)
                    }
                case .numberEntry:
                    XCTFail("vocabulary never uses the number pad")
                }
            }
        }
    }

    func testQuestionTypesFollowAge() throws {
        let g = try generator()
        var rng = SeededGenerator(seed: 2)

        let young = g.makeQuestions(count: 40, difficulty: DifficultyScale.difficulty(forAge: 4), recentlyCorrect: [], using: &rng)
        XCTAssertTrue(young.allSatisfy { q in
            if case .buildSequence = q.format { return false }
            return q.visual != nil || q.prompt.contains("Bild")
        }, "4-year-olds only get picture questions")

        let older = g.makeQuestions(count: 60, difficulty: DifficultyScale.difficulty(forAge: 11), recentlyCorrect: [], using: &rng)
        XCTAssertTrue(older.contains { $0.prompt.contains("Gegenteil") })
        XCTAssertTrue(older.contains { $0.prompt.contains("Gleiche") })
        XCTAssertTrue(older.contains { if case .buildSequence = $0.format { true } else { false } })
        XCTAssertFalse(older.contains { $0.prompt == "Welches Wort passt zum Bild?" }, "no picture-to-word at 11")
    }

    func testCorrectAnswersMatchTheWordList() throws {
        let g = try generator()
        let entries = words(g)
        var rng = SeededGenerator(seed: 3)
        for age in [6, 9, 12] {
            let questions = g.makeQuestions(count: 80, difficulty: DifficultyScale.difficulty(forAge: age), recentlyCorrect: [], using: &rng)
            for q in questions {
                let word = try XCTUnwrap(q.contentID?.replacingOccurrences(of: "vocab:", with: ""))
                let entry = try XCTUnwrap(entries[word])
                let answer = q.format.correctAnswerText
                if q.prompt.contains("Gegenteil") {
                    XCTAssertTrue((entry.antonyms ?? []).contains(answer), "\(answer) is not an opposite of \(word)")
                } else if q.prompt.contains("Gleiche") {
                    XCTAssertTrue((entry.synonyms ?? []).contains(answer), "\(answer) is not a synonym of \(word)")
                } else if q.prompt.hasPrefix("Was bedeutet") {
                    XCTAssertEqual(answer, entry.definition)
                } else if case .buildSequence = q.format {
                    XCTAssertEqual(answer, word)
                }
            }
        }
    }

    /// "riesig" (≈ gross) must never be a *wrong* option for "the opposite of klein".
    func testSynonymAndOppositeDistractorsAreNeverAlsoRight() throws {
        let g = try generator()
        let entries = words(g)
        var rng = SeededGenerator(seed: 4)
        let d = DifficultyScale.difficulty(forAge: 12)
        for _ in 0..<20 {
            for q in g.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng)
            where q.prompt.contains("Gegenteil") || q.prompt.contains("Gleiche") {
                guard case let .multipleChoice(options, index) = q.format,
                      let word = q.contentID?.replacingOccurrences(of: "vocab:", with: ""),
                      let entry = entries[word] else { continue }
                let family = g.family(of: entry)
                for (i, option) in options.enumerated() where i != index {
                    XCTAssertFalse(family.contains(option.text), "\(option.text) is related to \(word)")
                }
            }
        }
    }

    func testRecentlyCorrectWordsAreRarer() throws {
        let g = try generator()
        let d = DifficultyScale.difficulty(forAge: 4)
        let everyID = Set(g.words.map(VocabularyQuestionGenerator.contentID))
        let favourite = "vocab:Hund"
        var rng = SeededGenerator(seed: 5)
        var withHistory = 0, without = 0
        for _ in 0..<300 {
            withHistory += g.makeQuestions(count: 5, difficulty: d, recentlyCorrect: [favourite], using: &rng).filter { $0.contentID == favourite }.count
            without += g.makeQuestions(count: 5, difficulty: d, recentlyCorrect: everyID.subtracting([favourite]), using: &rng).filter { $0.contentID == favourite }.count
        }
        XCTAssertLessThan(withHistory, without)
    }

    // MARK: Tiles in the round

    @MainActor
    func testSequenceBuilding() {
        let subject = SubjectDescriptor(id: "vocabulary", languageCode: "de", provider: .wordList, file: "vocabulary.json", title: "Wörter", icon: "a", colorHex: "#2F86D6")
        let q = Question(subjectID: "vocabulary", prompt: "?", format: .buildSequence(tiles: ["u", "H", "n", "d", "x"], answer: ["H", "u", "n", "d"]))
        let vm = RoundViewModel(subject: subject, questions: [q], difficulty: DifficultyScale.difficulty(forAge: 8))

        vm.placeTile(1)
        vm.placeTile(1)
        XCTAssertEqual(vm.placedTileIndices, [1], "a tile can only be placed once")
        vm.placeTile(0)
        vm.placeTile(4)
        XCTAssertFalse(vm.canSubmitSequence, "3 of 4 slots filled")
        vm.placeTile(2)
        vm.placeTile(3)
        XCTAssertEqual(vm.placedTileIndices, [1, 0, 4, 2], "no more tiles than slots")
        XCTAssertTrue(vm.canSubmitSequence)

        vm.removePlacedTile(at: 2)          // take the stray "x" back
        XCTAssertEqual(vm.placedTileIndices, [1, 0, 2])
        vm.placeTile(3)
        XCTAssertEqual(vm.placedTileIndices, [1, 0, 2, 3])
        vm.submitSequence()
        XCTAssertEqual(vm.phase, .feedback(isCorrect: true))
        XCTAssertEqual(q.format.correctAnswerText, "Hund")
    }
}
