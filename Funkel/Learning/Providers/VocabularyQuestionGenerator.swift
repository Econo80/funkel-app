import Foundation

/// Builds vocabulary questions from a word list (provider kind `wordList`).
/// Question types unlock with age (PLAN.md §5.3); words are picked by the
/// shared eligibility and weighting rules.
struct VocabularyQuestionGenerator: QuestionProvider {
    typealias Word = WordList.Entry

    let subjectID: String
    let words: [Word]
    let phrasing: Phrasing

    /// Letters mixed into spelling tiles as distractors for older children.
    static let distractorLetters = Array("abcdefghiklmnoprstuäöü").map(String.init)

    static func contentID(for word: Word) -> String { "vocab:\(word.word)" }

    func makeQuestions<R: RandomNumberGenerator>(
        count: Int,
        difficulty: Difficulty,
        recentlyCorrect: Set<String>,
        using rng: inout R
    ) -> [Question] {
        let eligible = words.filter { difficulty.isEligible(minAge: $0.minAge, maxAge: $0.maxAge) }
        guard !eligible.isEmpty else { return [] }

        let typeWeights = VocabularyQuestionType.allCases.map { ($0, difficulty.vocabulary.questionTypeWeights[$0] ?? 0) }
        var usedWords: Set<String> = []
        var questions: [Question] = []
        var attempts = 0

        while questions.count < count && attempts < count * 20 {
            attempts += 1
            guard let type = WeightedPick.pick(typeWeights, using: &rng) else { break }

            var candidates = eligible.filter { supports($0, type, difficulty) && !usedWords.contains($0.word) }
            if candidates.isEmpty {
                // Small lists: allow repeats rather than ending the round early.
                candidates = eligible.filter { supports($0, type, difficulty) }
            }
            let weighted = candidates.map {
                ($0, difficulty.selectionWeight(minAge: $0.minAge, recentlyCorrect: recentlyCorrect.contains(Self.contentID(for: $0))))
            }
            guard let word = WeightedPick.pick(weighted, using: &rng),
                  let question = makeQuestion(type, word: word, pool: eligible, difficulty: difficulty, using: &rng)
            else { continue }

            usedWords.insert(word.word)
            questions.append(question)
        }
        return questions
    }

    // MARK: - Which words fit which type

    private func supports(_ word: Word, _ type: VocabularyQuestionType, _ difficulty: Difficulty) -> Bool {
        switch type {
        case .pictureToWord, .wordToPicture:
            return word.emoji != nil
        case .meaning:
            return word.definition != nil
        case .spelling:
            return word.word.count <= difficulty.vocabulary.spellingMaxLength
                && word.word.allSatisfy(\.isLetter)
                && (word.emoji != nil || word.definition != nil)
        case .opposite:
            return !(word.antonyms ?? []).isEmpty
        case .synonym:
            return !(word.synonyms ?? []).isEmpty
        }
    }

    // MARK: - Building questions

    private func makeQuestion<R: RandomNumberGenerator>(
        _ type: VocabularyQuestionType,
        word: Word,
        pool: [Word],
        difficulty: Difficulty,
        using rng: inout R
    ) -> Question? {
        let id = Self.contentID(for: word)
        let wrongCount = difficulty.answerOptionCount - 1

        switch type {
        case .pictureToWord:
            let others = pool.filter { $0.word != word.word && $0.emoji != nil && $0.emoji != word.emoji }
            let wrong = Array(others.shuffled(using: &rng).prefix(wrongCount)).map(display)
            guard let format = choice(correct: display(word), wrong: wrong, using: &rng) else { return nil }
            return Question(
                subjectID: subjectID, contentID: id,
                prompt: phrasing.text("vocab.pictureToWord"),
                visual: word.emoji.map(QuestionVisual.emoji),
                format: format
            )

        case .wordToPicture:
            guard let emoji = word.emoji else { return nil }
            let others = pool.filter { $0.word != word.word && $0.emoji != nil && $0.emoji != emoji }
            let wrong = Array(others.shuffled(using: &rng).prefix(wrongCount))
            guard wrong.count >= 1 else { return nil }
            let entries = ([word] + wrong).shuffled(using: &rng)
            let options = entries.enumerated().map { AnswerOption(id: $0.offset, text: display($0.element), emoji: $0.element.emoji) }
            let correctIndex = entries.firstIndex { $0.word == word.word } ?? 0
            return Question(
                subjectID: subjectID, contentID: id,
                prompt: phrasing.text("vocab.wordToPicture", ["word": display(word)]),
                format: .multipleChoice(options: options, correctIndex: correctIndex)
            )

        case .meaning:
            guard let definition = word.definition else { return nil }
            let others = pool.compactMap(\.definition).filter { $0 != definition }
            let wrong = Array(Set(others).sorted().shuffled(using: &rng).prefix(wrongCount))
            guard let format = choice(correct: definition, wrong: wrong, using: &rng) else { return nil }
            return Question(
                subjectID: subjectID, contentID: id,
                prompt: phrasing.text("vocab.meaning", ["word": word.word]),
                visual: difficulty.usesPictureOptions ? word.emoji.map(QuestionVisual.emoji) : nil,
                format: format
            )

        case .opposite, .synonym:
            let related = (type == .opposite ? word.antonyms : word.synonyms) ?? []
            guard let correct = related.randomElement(using: &rng) else { return nil }
            let wrong = Array(relatedWordPool(excluding: family(of: word)).shuffled(using: &rng).prefix(wrongCount))
            guard let format = choice(correct: correct, wrong: wrong, using: &rng) else { return nil }
            let key = type == .opposite ? "vocab.opposite" : "vocab.synonym"
            return Question(
                subjectID: subjectID, contentID: id,
                prompt: phrasing.text(key, ["word": word.word]),
                format: format
            )

        case .spelling:
            let letters = word.word.map(String.init)
            let extra = (0..<difficulty.vocabulary.spellingDistractorLetters).compactMap { _ in
                Self.distractorLetters.randomElement(using: &rng)
            }
            return Question(
                subjectID: subjectID, contentID: id,
                prompt: phrasing.text("vocab.spelling"),
                sentence: word.emoji == nil ? word.definition : nil,
                visual: word.emoji.map(QuestionVisual.emoji),
                format: .buildSequence(tiles: (letters + extra).shuffled(using: &rng), answer: letters),
                spoken: phrasing.text("vocab.spelling.spoken", ["word": word.word])
            )
        }
    }

    /// The word, its synonyms and antonyms, and theirs in turn. None of these may
    /// appear as a wrong answer, because some of them could also be right:
    /// "riesig" (≈ gross) is also an opposite of "klein".
    func family(of word: Word) -> Set<String> {
        var family = Set([word.word] + (word.synonyms ?? []) + (word.antonyms ?? []))
        let core = family
        for entry in words {
            let related = Set((entry.synonyms ?? []) + (entry.antonyms ?? []))
            if core.contains(entry.word) || !related.isDisjoint(with: core) {
                family.insert(entry.word)
                family.formUnion(related)
            }
        }
        return family
    }

    /// Distractors for synonym/opposite questions: every word and related word
    /// in the list, minus anything that could also be right.
    private func relatedWordPool(excluding excluded: Set<String>) -> [String] {
        var pool = Set<String>()
        for entry in words where entry.antonyms != nil || entry.synonyms != nil {
            pool.insert(entry.word)
            pool.formUnion(entry.synonyms ?? [])
            pool.formUnion(entry.antonyms ?? [])
        }
        return pool.subtracting(excluded).sorted()
    }

    private func choice<R: RandomNumberGenerator>(correct: String, wrong: [String], using rng: inout R) -> QuestionFormat? {
        var seen: Set<String> = [correct]
        let unique = wrong.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return nil }
        let values = ([correct] + unique).shuffled(using: &rng)
        let options = values.enumerated().map { AnswerOption(id: $0.offset, text: $0.element) }
        return .multipleChoice(options: options, correctIndex: values.firstIndex(of: correct) ?? 0)
    }

    /// Nouns with their article, as children learn them: "der Hund".
    private func display(_ word: Word) -> String {
        if let article = word.article, !article.isEmpty { return "\(article) \(word.word)" }
        return word.word
    }
}
