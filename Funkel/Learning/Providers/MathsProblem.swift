import Foundation

enum Arithmetic: String, CaseIterable, Sendable {
    case add, subtract, multiply, divide

    func apply(_ a: Int, _ b: Int) -> Int {
        switch self {
        case .add: a + b
        case .subtract: a - b
        case .multiply: a * b
        case .divide: b == 0 ? 0 : a / b
        }
    }

    init?(_ operation: MathsOperation) {
        switch operation {
        case .addition: self = .add
        case .subtraction: self = .subtract
        case .multiplication: self = .multiply
        case .division: self = .divide
        default: return nil
        }
    }

    var operation: MathsOperation {
        switch self {
        case .add: .addition
        case .subtract: .subtraction
        case .multiply: .multiplication
        case .divide: .division
        }
    }
}

/// The numbers behind one maths question, independent of language and layout.
struct MathsProblem: Equatable, Sendable {
    let operation: MathsOperation
    /// The underlying sum for equations, missing numbers and word problems.
    let arithmetic: Arithmetic?
    let a: Int
    let b: Int
    /// `a <op> b` (or the count, for counting/recognition).
    let result: Int
    /// What the child has to enter: `b` for missing numbers, otherwise `result`.
    let answer: Int
}

/// Builds `MathsProblem`s whose numbers stay inside the age's ranges
/// (PLAN.md §5.2). Pure apart from the injected random generator.
enum MathsProblemFactory {

    static func make<R: RandomNumberGenerator>(
        _ operation: MathsOperation,
        difficulty d: MathsDifficulty,
        arithmetic preferred: Arithmetic? = nil,
        using rng: inout R
    ) -> MathsProblem {
        switch operation {
        case .counting, .numberRecognition:
            let n = Int.random(in: 1...max(2, d.countingMax), using: &rng)
            return MathsProblem(operation: operation, arithmetic: nil, a: n, b: 0, result: n, answer: n)

        case .addition, .subtraction, .multiplication, .division:
            let kind = Arithmetic(operation) ?? .add
            let (a, b) = operands(for: kind, difficulty: d, wordProblem: false, using: &rng)
            let result = kind.apply(a, b)
            return MathsProblem(operation: operation, arithmetic: kind, a: a, b: b, result: result, answer: result)

        case .missingNumber:
            let kind = preferred ?? missingNumberArithmetic(difficulty: d, using: &rng)
            let (a, b) = operands(for: kind, difficulty: d, wordProblem: false, using: &rng)
            return MathsProblem(operation: operation, arithmetic: kind, a: a, b: b, result: kind.apply(a, b), answer: b)

        case .wordProblem:
            let kind = preferred ?? .add
            let (a, b) = operands(for: kind, difficulty: d, wordProblem: true, using: &rng)
            let result = kind.apply(a, b)
            return MathsProblem(operation: operation, arithmetic: kind, a: a, b: b, result: result, answer: result)
        }
    }

    /// The arithmetic kinds currently unlocked for this difficulty.
    static func unlockedArithmetic(_ d: MathsDifficulty) -> [Arithmetic] {
        var kinds: [Arithmetic] = [.add, .subtract]
        if d.operationWeights[.multiplication] != nil { kinds.append(.multiply) }
        if d.operationWeights[.division] != nil { kinds.append(.divide) }
        return kinds
    }

    private static func missingNumberArithmetic<R: RandomNumberGenerator>(difficulty d: MathsDifficulty, using rng: inout R) -> Arithmetic {
        let options = unlockedArithmetic(d).filter { $0 != .divide }
        return options.randomElement(using: &rng) ?? .add
    }

    private static func operands<R: RandomNumberGenerator>(
        for kind: Arithmetic,
        difficulty d: MathsDifficulty,
        wordProblem: Bool,
        using rng: inout R
    ) -> (Int, Int) {
        // Word problems avoid 0 and 1 so the German plural always fits ("2 Äpfel").
        let minOperand = wordProblem ? 2 : 1
        let maxSum = max(minOperand * 2, wordProblem ? d.wordProblemNumberMax : d.addSubResultMax)

        switch kind {
        case .add:
            let a = Int.random(in: minOperand...(maxSum - minOperand), using: &rng)
            let b = Int.random(in: minOperand...(maxSum - a), using: &rng)
            return (a, b)

        case .subtract:
            if d.allowsNegativeResults && !wordProblem && Double.random(in: 0..<1, using: &rng) < 0.25 {
                let a = Int.random(in: 1...max(1, maxSum / 2), using: &rng)
                let b = Int.random(in: (a + 1)...max(a + 1, maxSum), using: &rng)
                return (a, b)
            }
            let a = Int.random(in: (minOperand + 1)...max(minOperand + 1, maxSum), using: &rng)
            let b = Int.random(in: minOperand...(a - 1), using: &rng)
            return (a, b)

        case .multiply:
            let first = factor(d, wordProblem: wordProblem, using: &rng)
            let secondMax = wordProblem ? 10 : max(2, d.secondFactorMax)
            let second = Int.random(in: (wordProblem ? 2 : 1)...secondMax, using: &rng)
            return Bool.random(using: &rng) ? (first, second) : (second, first)

        case .divide:
            let divisor = factor(d, wordProblem: wordProblem, using: &rng)
            let quotientMax = wordProblem ? 10 : max(2, d.secondFactorMax)
            let quotient = Int.random(in: (wordProblem ? 2 : 1)...quotientMax, using: &rng)
            return (divisor * quotient, divisor)
        }
    }

    private static func factor<R: RandomNumberGenerator>(_ d: MathsDifficulty, wordProblem: Bool, using rng: inout R) -> Int {
        if d.restrictToEasyTables {
            return DifficultyTuning.easyTables.randomElement(using: &rng) ?? 2
        }
        let upper = wordProblem ? min(10, max(2, d.maxFactor)) : max(2, d.maxFactor)
        return Int.random(in: 2...upper, using: &rng)
    }
}

/// Plausible wrong answers: near misses a child might actually make.
enum MathsDistractors {
    static func make<R: RandomNumberGenerator>(
        for problem: MathsProblem,
        count: Int,
        allowsNegative: Bool,
        upperBound: Int? = nil,
        using rng: inout R
    ) -> [Int] {
        let answer = problem.answer
        var candidates = [answer - 1, answer + 1, answer - 2, answer + 2]

        switch problem.arithmetic {
        case .multiply?:
            candidates += [problem.a * (problem.b + 1), problem.a * max(0, problem.b - 1), (problem.a + 1) * problem.b]
        case .add?, .subtract?:
            if abs(answer) >= 10 { candidates += [answer + 10, answer - 10] }
        default:
            break
        }
        if answer >= 10, let swapped = Int(String(String(answer).reversed())), swapped != answer {
            candidates.append(swapped)
        }

        let floor = (problem.operation == .counting || problem.operation == .numberRecognition) ? 1 : 0
        var seen: Set<Int> = [answer]
        var result: [Int] = []
        for value in candidates.shuffled(using: &rng) where result.count < count {
            guard allowsNegative || value >= floor else { continue }
            if let upperBound, value > upperBound { continue }
            if seen.insert(value).inserted { result.append(value) }
        }

        // Fallback: widen the net until we have enough.
        var spread = 3
        while result.count < count && spread < 1000 {
            let value = answer + Int.random(in: -spread...spread, using: &rng)
            let inRange = (allowsNegative || value >= floor) && (upperBound.map { value <= $0 } ?? true)
            if inRange, seen.insert(value).inserted { result.append(value) }
            spread += 1
        }
        return result
    }
}
