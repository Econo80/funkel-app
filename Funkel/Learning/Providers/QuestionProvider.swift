import Foundation

/// Produces the questions for one round of a subject.
protocol QuestionProvider {
    /// - Parameter recentlyCorrect: content ids answered correctly in recent
    ///   rounds, so providers can down-weight repeats (PLAN.md §5.3).
    func makeQuestions<R: RandomNumberGenerator>(
        count: Int,
        difficulty: Difficulty,
        recentlyCorrect: Set<String>,
        using rng: inout R
    ) -> [Question]
}

extension QuestionProvider {
    func makeQuestions(count: Int, difficulty: Difficulty, recentlyCorrect: Set<String> = []) -> [Question] {
        var rng = SystemRandomNumberGenerator()
        return makeQuestions(count: count, difficulty: difficulty, recentlyCorrect: recentlyCorrect, using: &rng)
    }
}

/// Maps a subject's provider kind to its engine.
enum QuestionProviderFactory {

    /// Provider kinds with an engine in this build. Subjects using other kinds
    /// are shown as "coming soon".
    static func isAvailable(_ kind: ProviderKind) -> Bool {
        switch kind {
        case .maths, .wordList: true
        case .questionBank: false
        }
    }

    static func provider(for subject: SubjectDescriptor, content: ContentLibrary) throws -> (any QuestionProvider)? {
        switch subject.provider {
        case .maths:
            return MathsQuestionGenerator(
                subjectID: subject.id,
                content: try content.mathsContent(for: subject),
                phrasing: try content.phrasing(language: subject.languageCode)
            )
        case .wordList:
            return VocabularyQuestionGenerator(
                subjectID: subject.id,
                words: try content.wordList(for: subject).words,
                phrasing: try content.phrasing(language: subject.languageCode)
            )
        case .questionBank:
            return nil
        }
    }
}
