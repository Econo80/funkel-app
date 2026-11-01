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

    // MARK: Country and history (mirror web/tests/providers.test.ts)

    func testCountryQuestionsOnlyInThatCountry() throws {
        let base = try provider()
        func asked(_ country: Country?) -> [QuestionBank.Item] {
            var p = base
            p.country = country
            var ids = Set<String>()
            for seed in 0..<40 {
                var rng = SeededGenerator(seed: UInt64(seed))
                for q in p.makeQuestions(count: 20, difficulty: DifficultyScale.difficulty(forAge: 9), recentlyCorrect: [], using: &rng) {
                    if let id = q.contentID { ids.insert(id) }
                }
            }
            return base.items.filter { ids.contains($0.id) }
        }
        let swiss = asked(.switzerland)
        XCTAssertTrue(swiss.allSatisfy { $0.countries == nil || $0.countries!.contains("CH") })
        XCTAssertTrue(swiss.contains { $0.countries?.contains("CH") == true })
        XCTAssertFalse(swiss.contains { $0.prompt.contains("Bundesländer hat Deutschland") })
        XCTAssertTrue(asked(.germany).contains { $0.countries?.contains("DE") == true })
        XCTAssertTrue(asked(nil).allSatisfy { $0.countries == nil })
        for country in Country.allCases {
            for age in [6, 9, 12] {
                let d = DifficultyScale.difficulty(forAge: age)
                let own = base.items.filter { $0.countries?.contains(country.rawValue) == true && d.isEligible(minAge: $0.minAge, maxAge: $0.maxAge) }
                XCTAssertGreaterThanOrEqual(own.count, 5, "\(country) at \(age)")
            }
        }
    }

    func testNewQuestionsFirstThenTheOnesAskedLongestAgo() throws {
        var p = try provider()
        p.country = .switzerland
        let d = DifficultyScale.difficulty(forAge: 7)
        let pool = p.items.filter { d.isEligible(minAge: $0.minAge, maxAge: $0.maxAge) && p.isForCountry($0) }
        XCTAssertGreaterThan(pool.count, 150)
        var asked = Set<String>()
        for round in 0..<(pool.count / 10) {
            var rng = SeededGenerator(seed: UInt64(round))
            let ids = p.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng).compactMap(\.contentID)
            for id in ids {
                XCTAssertFalse(asked.contains(id), "round \(round) repeats \(id)")
                asked.insert(id)
            }
            p.seen = ProgressRecorder.withSeen(p.seen, asked: ids)
        }
        // Once everything was asked, the last round's questions don't come straight back.
        let all = pool.map(\.id)
        let recent = Array(all.suffix(10))
        p.seen = ProgressRecorder.withSeen(Array(all.dropLast(10)), asked: recent)
        var back = 0
        for seed in 100..<120 {
            var rng = SeededGenerator(seed: UInt64(seed))
            back += p.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng).filter { recent.contains($0.contentID ?? "") }.count
        }
        XCTAssertLessThan(back, 5)
    }

    func testSeenKeepsEachQuestionOnceNewestLast() {
        XCTAssertEqual(ProgressRecorder.withSeen(["a", "b", "c"], asked: ["d", "a", "d"]), ["b", "c", "d", "a"])
        let full = (0..<ProgressRecorder.seenContentLimit).map { "q\($0)" }
        XCTAssertEqual(ProgressRecorder.withSeen(full, asked: ["new"]).suffix(2), ["q\(ProgressRecorder.seenContentLimit - 1)", "new"])
        XCTAssertEqual(ProgressRecorder.withSeen(full, asked: ["new"]).count, ProgressRecorder.seenContentLimit)
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
