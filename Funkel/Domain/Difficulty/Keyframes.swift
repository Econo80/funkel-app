import Foundation

/// A piecewise-linear curve over effective age.
///
/// Values before the first or after the last keyframe are clamped. Steps
/// (e.g. "off below 7, on from 7") are expressed with two close keyframes,
/// such as `(6.9, 0), (7, 1.5)`.
struct Keyframes: Equatable, Sendable {
    struct Point: Equatable, Sendable {
        let age: Double
        let value: Double
    }

    let points: [Point]

    init(_ pairs: [(Double, Double)]) {
        precondition(!pairs.isEmpty, "Keyframes need at least one point")
        points = pairs
            .map { Point(age: $0.0, value: $0.1) }
            .sorted { $0.age < $1.age }
    }

    func value(at age: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if age <= first.age { return first.value }
        if age >= last.age { return last.value }

        for (lower, upper) in zip(points, points.dropFirst()) where age <= upper.age {
            let span = upper.age - lower.age
            guard span > 0 else { return upper.value }
            let t = (age - lower.age) / span
            return lower.value + (upper.value - lower.value) * t
        }
        return last.value
    }

    func intValue(at age: Double) -> Int {
        Int(value(at: age).rounded())
    }
}
