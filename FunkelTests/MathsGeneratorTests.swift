import XCTest
@testable import Funkel

final class MathsGeneratorTests: XCTestCase {

    private let ages = Array(DifficultyTuning.ageRange)

    // MARK: Problem factory

    func testProblemsRespectAgeRangesAtEveryAge() {
        var rng = SeededGenerator(seed: 42)
        for age in ages {
            let d = DifficultyScale.difficulty(forAge: age).maths
            for operation in MathsOperation.allCases {
                for _ in 0..<300 {
                    let wordKind = Arithmetic.allCases.randomElement(using: &rng)
                    let p = MathsProblemFactory.make(operation, difficulty: d, arithmetic: operation == .wordProblem ? wordKind : nil, using: &rng)
                    assertValid(p, difficulty: d, age: age)
                }
            }
        }
    }

    private func assertValid(_ p: MathsProblem, difficulty d: MathsDifficulty, age: Int, file: StaticString = #filePath, line: UInt = #line) {
        let context = "age \(age) \(p)"
        if let kind = p.arithmetic {
            XCTAssertEqual(kind.apply(p.a, p.b), p.result, context, file: file, line: line)
        }
        XCTAssertEqual(p.answer, p.operation == .missingNumber ? p.b : p.result, context, file: file, line: line)

        switch p.operation {
        case .counting, .numberRecognition:
            XCTAssert((1...max(2, d.countingMax)).contains(p.answer), context, file: file, line: line)
        case .addition:
            XCTAssertLessThanOrEqual(p.result, d.addSubResultMax, context, file: file, line: line)
        case .subtraction:
            if !d.allowsNegativeResults {
                XCTAssertGreaterThan(p.result, 0, context, file: file, line: line)
            }
        case .division:
            XCTAssertEqual(p.a % p.b, 0, "division must be exact: \(context)", file: file, line: line)
        case .wordProblem:
            XCTAssertGreaterThanOrEqual(min(p.a, p.b), 2, "word problems avoid 0 and 1: \(context)", file: file, line: line)
            XCTAssertGreaterThan(p.result, 0, context, file: file, line: line)
            if p.arithmetic == .divide {
                XCTAssertEqual(p.a % p.b, 0, context, file: file, line: line)
            }
        case .multiplication, .missingNumber:
            break
        }
    }

    func testEasyTablesOnlyBeforeAgeEightAndAHalf() {
        var rng = SeededGenerator(seed: 7)
        let d = DifficultyScale.difficulty(forAge: 8).maths
        XCTAssertTrue(d.restrictToEasyTables)
        for _ in 0..<200 {
            let p = MathsProblemFactory.make(.multiplication, difficulty: d, using: &rng)
            XCTAssertTrue(DifficultyTuning.easyTables.contains(p.a) || DifficultyTuning.easyTables.contains(p.b), "\(p)")
        }
    }

    // MARK: Distractors

    func testDistractorsAreUniqueAndNeverTheAnswer() {
        var rng = SeededGenerator(seed: 99)
        for age in ages {
            let d = DifficultyScale.difficulty(forAge: age)
            for operation in MathsOperation.allCases {
                for _ in 0..<100 {
                    let p = MathsProblemFactory.make(operation, difficulty: d.maths, using: &rng)
                    let wrong = MathsDistractors.make(for: p, count: 3, allowsNegative: d.maths.allowsNegativeResults, using: &rng)
                    XCTAssertEqual(wrong.count, 3)
                    XCTAssertEqual(Set(wrong).count, 3)
                    XCTAssertFalse(wrong.contains(p.answer))
                    if !d.maths.allowsNegativeResults {
                        XCTAssertTrue(wrong.allSatisfy { $0 >= 0 }, "\(p) → \(wrong)")
                    }
                }
            }
        }
    }

    // MARK: Questions

    private func generator() throws -> MathsQuestionGenerator {
        let library = ContentLibrary.bundled()
        let subject = try XCTUnwrap(library.language(code: "de")?.subject(id: "maths"))
        return try XCTUnwrap(QuestionProviderFactory.provider(for: subject, content: library) as? MathsQuestionGenerator)
    }

    func testRoundHasRequestedLengthAndValidFormats() throws {
        let generator = try generator()
        var rng = SeededGenerator(seed: 2026)
        for age in ages {
            let d = DifficultyScale.difficulty(forAge: age)
            let questions = generator.makeQuestions(count: 10, difficulty: d, recentlyCorrect: [], using: &rng)
            XCTAssertEqual(questions.count, 10)

            for q in questions {
                XCTAssertFalse(q.prompt.isEmpty)
                XCTAssertFalse(q.prompt.contains("{"), "unfilled placeholder: \(q.prompt)")
                switch q.format {
                case let .multipleChoice(options, correctIndex):
                    XCTAssertFalse(d.maths.usesNumberPad, "age \(age) should use the number pad")
                    XCTAssertEqual(options.count, d.answerOptionCount, "age \(age)")
                    XCTAssertTrue(options.indices.contains(correctIndex))
                    XCTAssertEqual(Set(options.map(\.text)).count, options.count, "duplicate options: \(options)")
                case .numberEntry:
                    XCTAssertTrue(d.maths.usesNumberPad, "age \(age) should use multiple choice")
                case .buildSequence:
                    XCTFail("maths never builds sequences")
                }
            }
        }
    }

    func testYoungChildrenGetCountingWithMatchingVisual() throws {
        let generator = try generator()
        var rng = SeededGenerator(seed: 4)
        let questions = generator.makeQuestions(count: 30, difficulty: DifficultyScale.difficulty(forAge: 4), recentlyCorrect: [], using: &rng)
        let counting = questions.compactMap { q -> (Int, Int)? in
            guard case let .countable(_, count)? = q.visual, case let .multipleChoice(options, index) = q.format else { return nil }
            return (count, Int(options[index].text) ?? -1)
        }
        XCTAssertFalse(counting.isEmpty)
        for (shown, answer) in counting {
            XCTAssertEqual(shown, answer)
        }
    }

    func testOlderChildrenGetWordProblems() throws {
        let generator = try generator()
        var rng = SeededGenerator(seed: 11)
        let questions = generator.makeQuestions(count: 60, difficulty: DifficultyScale.difficulty(forAge: 10), recentlyCorrect: [], using: &rng)
        let wordProblems = questions.filter { if case .emoji? = $0.visual { true } else { false } }
        XCTAssertFalse(wordProblems.isEmpty)
        XCTAssertTrue(wordProblems.allSatisfy { !$0.prompt.contains("{") })
    }

    func testSpokenTextUsesWordsNotSymbols() throws {
        let generator = try generator()
        var rng = SeededGenerator(seed: 5)
        let questions = generator.makeQuestions(count: 40, difficulty: DifficultyScale.difficulty(forAge: 9), recentlyCorrect: [], using: &rng)
        for q in questions where q.spoken != nil {
            XCTAssertFalse(q.spokenText.contains("·") || q.spokenText.contains("−"), q.spokenText)
        }
    }
}
