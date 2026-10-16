import Foundation

/// Procedural maths: turns `MathsProblem`s into questions phrased in the
/// learning language. Never runs out.
struct MathsQuestionGenerator: QuestionProvider {
    let subjectID: String
    let content: MathsContent
    let phrasing: Phrasing

    func makeQuestions<R: RandomNumberGenerator>(
        count: Int,
        difficulty: Difficulty,
        recentlyCorrect: Set<String>,
        using rng: inout R
    ) -> [Question] {
        let weights = MathsOperation.allCases.map { ($0, difficulty.maths.operationWeights[$0] ?? 0) }
        var questions: [Question] = []
        var seenKeys: Set<String> = []

        while questions.count < count {
            let operation = WeightedPick.pick(weights, using: &rng) ?? .addition
            var candidate = makeQuestion(operation, difficulty: difficulty, using: &rng)
            // Avoid repeats within a round; small ranges (age 4) may force a few.
            var attempts = 0
            while seenKeys.contains(candidate.key) && attempts < 8 {
                candidate = makeQuestion(operation, difficulty: difficulty, using: &rng)
                attempts += 1
            }
            seenKeys.insert(candidate.key)
            questions.append(candidate.question)
        }
        return questions
    }

    // MARK: - Building one question

    private func makeQuestion<R: RandomNumberGenerator>(
        _ operation: MathsOperation,
        difficulty: Difficulty,
        using rng: inout R
    ) -> (question: Question, key: String) {
        let maths = difficulty.maths

        switch operation {
        case .counting:
            let problem = MathsProblemFactory.make(.counting, difficulty: maths, using: &rng)
            let item = randomItem(using: &rng)
            let question = Question(
                subjectID: subjectID,
                prompt: phrasing.text("maths.counting", ["items": item.plural]),
                visual: .countable(symbol: item.emoji, count: problem.answer),
                format: answerFormat(for: problem, difficulty: difficulty, upperBound: maths.countingMax + 2, using: &rng)
            )
            return (question, "count-\(problem.answer)")

        case .numberRecognition:
            let problem = MathsProblemFactory.make(.numberRecognition, difficulty: maths, using: &rng)
            let item = randomItem(using: &rng)
            let wrong = MathsDistractors.make(
                for: problem,
                count: difficulty.answerOptionCount - 1,
                allowsNegative: false,
                upperBound: max(problem.answer + 2, maths.countingMax),
                using: &rng
            )
            let values = ([problem.answer] + wrong).shuffled(using: &rng)
            let options = values.enumerated().map { index, value in
                AnswerOption(id: index, text: String(value), emoji: String(repeating: item.emoji, count: value))
            }
            let question = Question(
                subjectID: subjectID,
                prompt: phrasing.text("maths.numberRecognition", ["n": String(problem.answer), "items": item.plural]),
                visual: .equation(String(problem.answer)),
                format: .multipleChoice(options: options, correctIndex: values.firstIndex(of: problem.answer) ?? 0)
            )
            return (question, "recognise-\(problem.answer)")

        case .addition, .subtraction, .multiplication, .division:
            let problem = MathsProblemFactory.make(operation, difficulty: maths, using: &rng)
            guard let kind = problem.arithmetic else { break }
            let written = "\(problem.a) \(symbol(kind)) \(problem.b)"
            let spoken = "\(problem.a) \(word(kind)) \(problem.b)"
            let question = Question(
                subjectID: subjectID,
                prompt: phrasing.text("maths.equation", ["equation": written]),
                visual: .equation("\(written) = ?"),
                format: answerFormat(for: problem, difficulty: difficulty, using: &rng),
                spoken: phrasing.text("maths.equation", ["equation": spoken])
            )
            return (question, written)

        case .missingNumber:
            let problem = MathsProblemFactory.make(.missingNumber, difficulty: maths, using: &rng)
            guard let kind = problem.arithmetic else { break }
            let written = "\(problem.a) \(symbol(kind)) ? = \(problem.result)"
            let spoken = "\(problem.a) \(word(kind)) \(phrasing.text("maths.word.blank")) \(phrasing.text("maths.word.equals")) \(problem.result)"
            let question = Question(
                subjectID: subjectID,
                prompt: phrasing.text("maths.missingNumber"),
                visual: .equation(written),
                format: answerFormat(for: problem, difficulty: difficulty, using: &rng),
                spoken: phrasing.text("maths.missingNumber") + " " + spoken
            )
            return (question, written)

        case .wordProblem:
            let unlocked = MathsProblemFactory.unlockedArithmetic(maths)
            let templates = content.wordProblems.filter { template in
                Double(template.minAge) <= difficulty.effectiveAge
                    && Arithmetic(template.operation).map { unlocked.contains($0) } == true
            }
            guard let template = templates.randomElement(using: &rng),
                  let kind = Arithmetic(template.operation) else { break }

            let problem = MathsProblemFactory.make(.wordProblem, difficulty: maths, arithmetic: kind, using: &rng)
            let item = randomItem(using: &rng)
            let name = content.names.randomElement(using: &rng) ?? ""
            let text = Phrasing(templates: ["t": template.template]).text("t", [
                "name": name,
                "a": String(problem.a),
                "b": String(problem.b),
                "item": item.singular,
                "items": item.plural,
            ])
            let question = Question(
                subjectID: subjectID,
                prompt: text,
                visual: .emoji(item.emoji),
                format: answerFormat(for: problem, difficulty: difficulty, using: &rng)
            )
            return (question, "word-\(problem.a)-\(kind.rawValue)-\(problem.b)")
        }

        // Unreachable in practice; fall back to a simple sum.
        return makeQuestion(.addition, difficulty: difficulty, using: &rng)
    }

    private func answerFormat<R: RandomNumberGenerator>(
        for problem: MathsProblem,
        difficulty: Difficulty,
        upperBound: Int? = nil,
        using rng: inout R
    ) -> QuestionFormat {
        if difficulty.maths.usesNumberPad {
            return .numberEntry(answer: problem.answer)
        }
        let wrong = MathsDistractors.make(
            for: problem,
            count: difficulty.answerOptionCount - 1,
            allowsNegative: difficulty.maths.allowsNegativeResults,
            upperBound: upperBound,
            using: &rng
        )
        let values = ([problem.answer] + wrong).shuffled(using: &rng)
        let options = values.enumerated().map { AnswerOption(id: $0.offset, text: String($0.element)) }
        return .multipleChoice(options: options, correctIndex: values.firstIndex(of: problem.answer) ?? 0)
    }

    private func randomItem<R: RandomNumberGenerator>(using rng: inout R) -> MathsContent.Item {
        content.items.randomElement(using: &rng) ?? MathsContent.Item(singular: "Stern", plural: "Sterne", emoji: "⭐️")
    }

    private func symbol(_ kind: Arithmetic) -> String {
        switch kind {
        case .add: phrasing.text("maths.symbol.plus")
        case .subtract: phrasing.text("maths.symbol.minus")
        case .multiply: phrasing.text("maths.symbol.times")
        case .divide: phrasing.text("maths.symbol.divide")
        }
    }

    private func word(_ kind: Arithmetic) -> String {
        switch kind {
        case .add: phrasing.text("maths.word.plus")
        case .subtract: phrasing.text("maths.word.minus")
        case .multiply: phrasing.text("maths.word.times")
        case .divide: phrasing.text("maths.word.divide")
        }
    }
}
