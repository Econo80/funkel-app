import Foundation

/// Broad age bands, used for phrasing and layout choices — never for limits.
/// Numeric limits always come from the continuous keyframes.
enum AgeTier: String, CaseIterable, Sendable {
    case early          // 4–5
    case lowerPrimary   // 6–7
    case upperPrimary   // 8–9
    case middle         // 10–11
    case upper          // 12–14

    init(effectiveAge: Double) {
        switch effectiveAge {
        case ..<6: self = .early
        case ..<8: self = .lowerPrimary
        case ..<10: self = .upperPrimary
        case ..<12: self = .middle
        default: self = .upper
        }
    }
}

enum MathsOperation: String, CaseIterable, Codable, Sendable {
    case counting
    case numberRecognition
    case addition
    case subtraction
    case multiplication
    case division
    case wordProblem
    case missingNumber
}

enum VocabularyQuestionType: String, CaseIterable, Codable, Sendable {
    case pictureToWord
    case wordToPicture
    case meaning
    case spelling
    case opposite
    case synonym
}

struct MathsDifficulty: Equatable, Sendable {
    /// Normalised to sum to 1. Operations with weight 0 are absent.
    var operationWeights: [MathsOperation: Double]
    var countingMax: Int
    var addSubResultMax: Int
    var maxFactor: Int
    var secondFactorMax: Int
    var restrictToEasyTables: Bool
    var allowsNegativeResults: Bool
    var usesNumberPad: Bool
    var wordProblemNumberMax: Int
}

struct VocabularyDifficulty: Equatable, Sendable {
    var questionTypeWeights: [VocabularyQuestionType: Double]
    var spellingMaxLength: Int
    var spellingDistractorLetters: Int
}

/// A snapshot of everything content and generators need to pitch a round.
/// Produced only by `DifficultyScale`.
struct Difficulty: Equatable, Sendable {
    let effectiveAge: Double
    /// 0.0 at age 4, 1.0 at age 14.
    let level: Double
    let tier: AgeTier

    var answerOptionCount: Int
    var usesPictureOptions: Bool
    var allowsGentleTimer: Bool
    var timerSeconds: Int

    var maths: MathsDifficulty
    var vocabulary: VocabularyDifficulty

    // MARK: Content selection (PLAN.md §5.3)

    func isEligible(minAge: Int, maxAge: Int?) -> Bool {
        let slack = DifficultyTuning.eligibilitySlack
        let upper = Double(maxAge ?? DifficultyTuning.maxAge)
        return Double(minAge) <= effectiveAge + slack && upper >= effectiveAge - slack
    }

    func selectionWeight(minAge: Int, recentlyCorrect: Bool) -> Double {
        let inCurrentBand = Double(minAge) >= effectiveAge - DifficultyTuning.currentBandWidth
        let base = inCurrentBand ? DifficultyTuning.currentBandWeight : DifficultyTuning.reviewWeight
        return recentlyCorrect ? base * DifficultyTuning.recentlyCorrectMultiplier : base
    }
}
