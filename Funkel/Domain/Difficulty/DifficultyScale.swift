import Foundation

/// A subject's level: years above (+) or below (−) the real age, and the run of perfect rounds.
struct Adaptivity: Equatable {
    var adjustment: Double
    var perfectRounds: Int
}

/// The age → difficulty scaling function. Pure and deterministic.
/// See PLAN.md §5 for the rules and `DifficultyTuning` for the numbers.
enum DifficultyScale {

    static func effectiveAge(age: Int, adjustment: Double) -> Double {
        let clampedAdjustment = adjustment.clamped(to: adjustmentRange)
        let raw = Double(age) + clampedAdjustment
        return raw.clamped(to: Double(DifficultyTuning.minAge)...Double(DifficultyTuning.maxAge))
    }

    static func difficulty(forAge age: Int, adjustment: Double = 0) -> Difficulty {
        difficulty(effectiveAge: effectiveAge(age: age, adjustment: adjustment))
    }

    static func difficulty(effectiveAge a: Double) -> Difficulty {
        typealias T = DifficultyTuning
        let span = Double(T.maxAge - T.minAge)

        return Difficulty(
            effectiveAge: a,
            level: ((a - Double(T.minAge)) / span).clamped(to: 0...1),
            tier: AgeTier(effectiveAge: a),
            answerOptionCount: T.answerOptionCount.intValue(at: a),
            usesPictureOptions: a < T.pictureOptionsBelowAge,
            allowsGentleTimer: a >= T.gentleTimerFromAge,
            timerSeconds: T.timerSeconds.intValue(at: a),
            maths: MathsDifficulty(
                operationWeights: normalised(T.mathsOperationWeights, at: a),
                countingMax: T.countingMax.intValue(at: a),
                addSubResultMax: T.addSubResultMax.intValue(at: a),
                maxFactor: T.maxFactor.intValue(at: a),
                secondFactorMax: T.secondFactorMax.intValue(at: a),
                restrictToEasyTables: a < T.easyTablesBelowAge,
                allowsNegativeResults: a >= T.negativeResultsFromAge,
                usesNumberPad: a >= T.numberPadFromAge,
                wordProblemNumberMax: min(T.addSubResultMax.intValue(at: a), T.wordProblemNumberCap)
            ),
            vocabulary: VocabularyDifficulty(
                questionTypeWeights: normalised(T.vocabularyTypeWeights, at: a),
                spellingMaxLength: T.spellingMaxLength.intValue(at: a),
                spellingDistractorLetters: T.spellingDistractorLetters.intValue(at: a)
            )
        )
    }

    static let adjustmentRange = -DifficultyTuning.maxAdjustment...DifficultyTuning.maxAdjustmentUp

    /// Adaptivity after a round (PLAN.md §5.4): 90 %+ steps up a little; from
    /// the second perfect round in a row each perfect round steps up faster
    /// ("boosted"); under 50 % steps back down and ends the run.
    static func nextAdaptivity(_ current: Adaptivity, correct: Int, total: Int) -> (adaptivity: Adaptivity, boosted: Bool) {
        typealias T = DifficultyTuning
        guard total > 0 else { return (current, false) }
        let score = Double(correct) / Double(total)
        let perfectRounds = score >= 1 ? current.perfectRounds + 1 : 0
        let boosted = perfectRounds >= T.perfectRoundsForBoost && current.adjustment < T.maxAdjustmentUp
        var next = current.adjustment
        if boosted {
            next += T.boostStepUp
        } else if score >= T.promoteThreshold {
            next += T.adjustmentStepUp
        } else if score < T.easeThreshold {
            next -= T.adjustmentStepDown
        }
        return (Adaptivity(adjustment: next.clamped(to: adjustmentRange), perfectRounds: perfectRounds), boosted)
    }

    /// One round on its own, without a run of perfect rounds.
    static func nextAdjustment(current: Double, correct: Int, total: Int) -> Double {
        nextAdaptivity(Adaptivity(adjustment: current, perfectRounds: 0), correct: correct, total: total).adaptivity.adjustment
    }

    private static func normalised<Key: Hashable>(_ curves: [Key: Keyframes], at age: Double) -> [Key: Double] {
        let raw = curves.mapValues { max(0, $0.value(at: age)) }.filter { $0.value > 0 }
        let total = raw.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return raw.mapValues { $0 / total }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
