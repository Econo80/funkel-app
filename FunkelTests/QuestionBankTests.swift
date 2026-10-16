import XCTest
@testable import Funkel

final class QuestionBankTests: XCTestCase {

    private func provider() throws -> QuestionBankProvider {
        let library = ContentLibrary.bundled()
        let subject = try XCTUnwrap(library.language(code: "de")?.subject(id: "generalKnowledge"))
        return try XCTUnwrap(QuestionProviderFactory.provider(for: subject, content: library) as? QuestionBankProvider)
    }

    private func item(_ id: String, in p: QuestionBankProvider) throws -> QuestionBank.Item {
        try XCTUnwrap(p.items.first { $0.id == id })
    }

    func testEveryBundledItemIsUsable() throws {
        let p = try provider()
        XCTAssertGreaterThanOrEqual(p.items.count, 100)
        for item in p.items {
            XCTAssertTrue(p.isUsable(item), item.id)
        }
    }

    func testFullRoundsWithoutRepeatsAtEveryAge() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 10)
        for age in DifficultyTuning.ageRange {
            let d = DifficultyScale.difficulty(forAge: age)
            let questions = p.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng)
            XCTAssertEqual(questions.count, 10, "age \(age)")
            XCTAssertEqual(Set(questions.compactMap(\.contentID)).count, questions.count, "repeat at age \(age)")
            for q in questions {
                let source = try item(try XCTUnwrap(q.contentID), in: p)
                XCTAssertTrue(d.isEligible(minAge: source.minAge, maxAge: source.maxAge), "\(source.id) not for age \(age)")
            }
        }
    }

    func testMultipleChoiceKeepsTheCorrectAnswerAndTrimsToAge() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 11)
        for age in [4, 7, 12] {
            let d = DifficultyScale.difficulty(forAge: age)
            for _ in 0..<10 {
                for q in p.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng) {
                    guard case let .multipleChoice(options, index) = q.format else { continue }
                    let source = try item(try XCTUnwrap(q.contentID), in: p)
                    XCTAssertEqual(options[index].text, source.correct, source.id)
                    XCTAssertLessThanOrEqual(options.count, d.answerOptionCount)
                    XCTAssertEqual(Set(options.map(\.text)).count, options.count)
                    XCTAssertTrue(options.allSatisfy { source.options?.contains($0.text) == true })
                }
            }
        }
    }

    func testSequencesAddDistractorsOnlyForOlderChildren() throws {
        let p = try provider()
        let butterfly = try item("gk-de-0030", in: p)
        let solo = QuestionBankProvider(subjectID: "generalKnowledge", items: [butterfly], phrasing: Phrasing(templates: [:]))
        var rng = SeededGenerator(seed: 12)

        let young = solo.makeQuestions(count: 1, difficulty: DifficultyScale.difficulty(forAge: 6), recentlyCorrect: [], using: &rng)
        let older = solo.makeQuestions(count: 1, difficulty: DifficultyScale.difficulty(forAge: 9), recentlyCorrect: [], using: &rng)

        guard case let .buildSequence(youngTiles, answer)? = young.first?.format,
              case let .buildSequence(olderTiles, _)? = older.first?.format else {
            return XCTFail("expected sequence questions")
        }
        XCTAssertEqual(answer, ["Ei", "Raupe", "Puppe", "Schmetterling"])
        XCTAssertEqual(Set(youngTiles), Set(answer))
        XCTAssertTrue(olderTiles.contains("Kaulquappe"))
    }

    func testSmallBankGivesShorterRoundInsteadOfRepeats() throws {
        let p = try provider()
        let two = Array(p.items.filter { $0.minAge == 4 }.prefix(2))
        let tiny = QuestionBankProvider(subjectID: "generalKnowledge", items: two, phrasing: Phrasing(templates: [:]))
        let questions = tiny.makeQuestions(count: 10, difficulty: DifficultyScale.difficulty(forAge: 4))
        XCTAssertEqual(questions.count, 2)
    }

    func testRoundsMixCategories() throws {
        let p = try provider()
        var rng = SeededGenerator(seed: 13)
        for _ in 0..<20 {
            let questions = p.makeQuestions(count: 10, difficulty: DifficultyScale.difficulty(forAge: 10), recentlyCorrect: [], using: &rng)
            let categories = try questions.map { try item(try XCTUnwrap($0.contentID), in: p).category ?? "" }
            XCTAssertGreaterThanOrEqual(Set(categories).count, 3, "\(categories)")
        }
    }

    func testMalformedItemsAreSkipped() throws {
        let json = """
        { "questions": [
          { "id": "ok", "minAge": 4, "format": "multipleChoice", "prompt": "?", "options": ["a", "b", "c"], "correct": "a" },
          { "id": "badCorrect", "minAge": 4, "format": "multipleChoice", "prompt": "?", "options": ["a", "b"], "correct": "z" },
          { "id": "noAnswer", "minAge": 4, "format": "buildSequence", "prompt": "?" }
        ] }
        """
        let bank = try JSONDecoder().decode(QuestionBank.self, from: Data(json.utf8))
        let p = QuestionBankProvider(subjectID: "x", items: bank.questions, phrasing: Phrasing(templates: [:]))
        let questions = p.makeQuestions(count: 5, difficulty: DifficultyScale.difficulty(forAge: 6))
        XCTAssertEqual(questions.map(\.contentID), ["ok"])
    }
}
