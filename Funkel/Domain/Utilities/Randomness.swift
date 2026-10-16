import Foundation

/// Deterministic generator (SplitMix64) so tests and previews are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum WeightedPick {
    /// Picks one item proportionally to its weight. Order of `items` must be
    /// stable for seeded results to be reproducible.
    static func pick<T, R: RandomNumberGenerator>(_ items: [(T, Double)], using rng: inout R) -> T? {
        let positive = items.filter { $0.1 > 0 }
        let total = positive.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return items.first?.0 }

        var roll = Double.random(in: 0..<total, using: &rng)
        for (item, weight) in positive {
            if roll < weight { return item }
            roll -= weight
        }
        return positive.last?.0
    }
}
