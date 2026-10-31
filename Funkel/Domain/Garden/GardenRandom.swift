import Foundation

/// The web app's random helpers (web/src/domain/random.ts), so a farm's daily
/// orders come out the same in both apps for the same child and day.
final class GardenRandom {
    private var state: UInt32
    private let system: Bool

    /// Deterministic generator (mulberry32), like the web app's `seededRng`.
    init(seed: Int32) {
        state = UInt32(bitPattern: seed)
        system = false
    }

    private init() {
        state = 0
        system = true
    }

    /// `Math.random` in the web app.
    static func system() -> GardenRandom { GardenRandom() }

    /// A number in [0, 1).
    func next() -> Double {
        if system { return Double.random(in: 0..<1) }
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }

    /// Integer in [min, max], inclusive.
    func int(_ min: Int, _ max: Int) -> Int {
        max <= min ? min : min + Int(next() * Double(max - min + 1))
    }

    func element<T>(_ items: [T]) -> T? {
        items.isEmpty ? nil : items[Int(next() * Double(items.count))]
    }

    func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        var i = result.count - 1
        while i > 0 {
            let j = Int(next() * Double(i + 1))
            result.swapAt(i, j)
            i -= 1
        }
        return result
    }

    /// The web app's string hash: `(h * 31 + charCode) | 0`, starting at 7.
    static func hash(_ text: String) -> Int32 {
        text.unicodeScalars.reduce(Int32(7)) { h, scalar in
            let code = Int32(String(scalar).utf16.first ?? 0)
            return h &* 31 &+ code
        }
    }
}
