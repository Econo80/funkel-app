import Foundation

/// Every tunable number behind age-based difficulty lives here.
///
/// The tables mirror PLAN.md §5 — keep the two in sync when you tune.
/// Keyframes are `(effectiveAge, value)` pairs, linearly interpolated.
enum DifficultyTuning {

    // MARK: - Age bounds & adaptivity (PLAN.md §5, §5.4)

    static let minAge = 4
    static let maxAge = 14
    static let ageRange = minAge...maxAge

    /// How far below the real age a struggling child can go.
    static let maxAdjustment = 1.5
    /// How far above the real age a child who gets everything right can go.
    static let maxAdjustmentUp = 3.0
    static let adjustmentStepUp = 0.15        // score ≥ 90 %
    /// From this many perfect rounds in a row, each further perfect round steps up faster.
    static let perfectRoundsForBoost = 2
    static let boostStepUp = 0.5
    static let adjustmentStepDown = 0.3       // score < 50 %
    static let promoteThreshold = 0.9
    static let easeThreshold = 0.5

    // MARK: - General (PLAN.md §5.1)

    static let answerOptionCount = Keyframes([(4, 3), (7.4, 3), (7.5, 4), (14, 4)])
    static let pictureOptionsBelowAge = 7.0
    static let gentleTimerFromAge = 9.0
    static let timerSeconds = Keyframes([(9, 45), (10, 40), (12, 30), (14, 25)])
    static let numberPadFromAge = 8.0

    // MARK: - Maths operation weights (PLAN.md §5.2)

    static let mathsOperationWeights: [MathsOperation: Keyframes] = [
        .counting:          Keyframes([(4, 6), (5, 4), (6, 1), (7, 0)]),
        .numberRecognition: Keyframes([(4, 4), (5, 3), (6, 1), (7, 0)]),
        .addition:          Keyframes([(4, 0), (5, 3), (6, 5), (7, 4), (8, 3), (9, 2), (14, 2)]),
        .subtraction:       Keyframes([(4, 0), (5, 1), (6, 3), (7, 4), (8, 3), (9, 2), (14, 2)]),
        .multiplication:    Keyframes([(6, 0), (7, 0.5), (8, 3), (14, 3)]),
        .division:          Keyframes([(7, 0), (8, 1), (9, 2), (10, 3), (14, 3)]),
        .wordProblem:       Keyframes([(6, 0), (7, 1), (8, 1.5), (9, 2), (10, 2), (12, 2.5), (14, 3)]),
        .missingNumber:     Keyframes([(6, 0), (7, 1), (8, 1.5), (9, 1.5), (10, 2), (14, 2)]),
    ]

    // MARK: - Maths ranges (PLAN.md §5.2)

    static let countingMax = Keyframes([(4, 5), (5, 10), (6, 12)])
    static let addSubResultMax = Keyframes([(4, 5), (5, 10), (6, 20), (7, 50), (8, 100), (10, 500), (12, 1000), (14, 5000)])
    static let maxFactor = Keyframes([(7, 5), (8, 5), (10, 10), (12, 12), (14, 20)])
    static let secondFactorMax = Keyframes([(7, 10), (10, 10), (12, 20), (14, 25)])
    /// Below this age the first factor comes only from `easyTables`.
    static let easyTablesBelowAge = 8.5
    static let easyTables = [2, 5, 10]
    static let negativeResultsFromAge = 12.0
    static let wordProblemNumberCap = 100

    // MARK: - Vocabulary (PLAN.md §5.3)

    static let vocabularyTypeWeights: [VocabularyQuestionType: Keyframes] = [
        .pictureToWord: Keyframes([(4, 4), (7, 2), (9, 0.5), (10, 0)]),
        .wordToPicture: Keyframes([(4, 4), (7, 1), (9, 0)]),
        .meaning:       Keyframes([(5.9, 0), (6, 2), (8, 3), (14, 3)]),
        .spelling:      Keyframes([(5.4, 0), (5.5, 1.5), (7, 3), (14, 2.5)]),
        .opposite:      Keyframes([(6.9, 0), (7, 1.5), (10, 2), (14, 2)]),
        .synonym:       Keyframes([(7.9, 0), (8, 1.5), (14, 2.5)]),
    ]
    static let spellingMaxLength = Keyframes([(5, 4), (7, 6), (10, 10), (12, 14)])
    static let spellingDistractorLetters = Keyframes([(7.9, 0), (8, 1), (10, 2), (12, 3)])

    // MARK: - Content selection (PLAN.md §5.3)

    static let eligibilitySlack = 0.5
    static let currentBandWidth = 2.0
    static let currentBandWeight = 3.0
    static let reviewWeight = 1.0
    static let recentlyCorrectMultiplier = 0.2
}
