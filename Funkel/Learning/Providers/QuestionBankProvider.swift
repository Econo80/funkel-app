import Foundation

/// Authored questions in generic formats (provider kind `questionBank`).
///
/// Used by General Knowledge today and by Grammar later: articles, verb forms
/// and sentence building are all `multipleChoice` (optionally with a `___`
/// gap sentence) or `buildSequence`, so a new language's grammar is content only.
struct QuestionBankProvider: QuestionProvider {
    let subjectID: String
    let items: [QuestionBank.Item]
    let phrasing: Phrasing

    /// Wrong tiles are mixed into sequence questions from this age.
    static let sequenceDistractorsFromAge = 8.0
    /// Picking a question halves the weight of the rest of its category, so a
    /// round mixes animals, geography, the body and so on.
    static let sameCategoryDamping = 0.5

    func makeQuestions<R: RandomNumberGenerator>(
        count: Int,
        difficulty: Difficulty,
        recentlyCorrect: Set<String>,
        using rng: inout R
    ) -> [Question] {
        var remaining = items.filter { isUsable($0) && difficulty.isEligible(minAge: $0.minAge, maxAge: $0.maxAge) }
        var categoryDamping: [String: Double] = [:]
        var questions: [Question] = []

        // A short bank yields a shorter round rather than repeating a question.
        while questions.count < count, !remaining.isEmpty {
            let weighted = remaining.map { item in
                let base = difficulty.selectionWeight(minAge: item.minAge, recentlyCorrect: recentlyCorrect.contains(item.id))
                return (item.id, base * (categoryDamping[item.category ?? ""] ?? 1))
            }
            guard let id = WeightedPick.pick(weighted, using: &rng),
                  let index = remaining.firstIndex(where: { $0.id == id }) else { break }
            let item = remaining.remove(at: index)
            categoryDamping[item.category ?? "", default: 1] *= Self.sameCategoryDamping

            if let question = makeQuestion(item, difficulty: difficulty, using: &rng) {
                questions.append(question)
            }
        }
        return questions
    }

    /// Defensive: malformed items are skipped, never crash a round.
    /// (`scripts/validate_content.py` reports them at authoring time.)
    func isUsable(_ item: QuestionBank.Item) -> Bool {
        switch item.format {
        case .multipleChoice:
            guard let options = item.options, let correct = item.correct else { return false }
            return options.contains(correct) && Set(options).count >= 2
        case .buildSequence:
            return (item.answer?.count ?? 0) >= 2
        }
    }

    private func makeQuestion<R: RandomNumberGenerator>(
        _ item: QuestionBank.Item,
        difficulty: Difficulty,
        using rng: inout R
    ) -> Question? {
        let format: QuestionFormat
        switch item.format {
        case .multipleChoice:
            guard let options = item.options, let correct = item.correct else { return nil }
            var seen: Set<String> = [correct]
            let wrong = options.filter { seen.insert($0).inserted }
            let chosen = [correct] + wrong.shuffled(using: &rng).prefix(difficulty.answerOptionCount - 1)
            let values = chosen.shuffled(using: &rng)
            format = .multipleChoice(
                options: values.enumerated().map { AnswerOption(id: $0.offset, text: $0.element) },
                correctIndex: values.firstIndex(of: correct) ?? 0
            )

        case .buildSequence:
            guard let answer = item.answer else { return nil }
            let extra = difficulty.effectiveAge >= Self.sequenceDistractorsFromAge ? (item.distractors ?? []) : []
            format = .buildSequence(tiles: (answer + extra).shuffled(using: &rng), answer: answer)
        }

        let prompt = item.prompt.isEmpty ? phrasing.text("sequence.build") : item.prompt
        return Question(
            subjectID: subjectID,
            contentID: item.id,
            prompt: prompt,
            sentence: item.sentence,
            visual: item.emoji.map(QuestionVisual.emoji),
            format: format,
            explanation: item.explanation
        )
    }
}
