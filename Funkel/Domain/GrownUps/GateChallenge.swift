import Foundation

/// The grown-up gate: a two-digit × one-digit multiplication (e.g. 14 × 7).
/// Easy for an adult, out of reach for most young children. Deliberately
/// light: it keeps little ones out of settings, it isn't security.
struct GateChallenge: Equatable {
    static let firstFactorRange = 12...19
    static let secondFactorRange = 3...9

    let a: Int
    let b: Int

    var answer: Int { a * b }

    static func random<R: RandomNumberGenerator>(using rng: inout R) -> GateChallenge {
        GateChallenge(a: Int.random(in: firstFactorRange, using: &rng), b: Int.random(in: secondFactorRange, using: &rng))
    }

    static func random() -> GateChallenge {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }

    func isCorrect(_ input: String) -> Bool {
        Int(input.trimmingCharacters(in: .whitespaces)) == answer
    }
}
