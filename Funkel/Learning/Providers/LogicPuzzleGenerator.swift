import Foundation

/// The kinds of Denken puzzles; the raw values are the web app's skill ids
/// (the catalog has "skill.<id>" for each).
enum LogicKind: String, CaseIterable, Sendable {
    case pattern
    case oddOneOut
    case numberSequence
    case matrix
    case analogy
}

/// "Denken": reasoning puzzles like the ones in classic reasoning tests, made
/// up fresh for every round and graded by age: continue a pattern, find the odd
/// one out, number sequences, 3×3 picture fields and picture analogies.
/// Groups and analogies come from `Content/<lang>/logic.json`; everything else
/// is generated. Mirrors web/src/providers/logic.ts.
struct LogicPuzzleGenerator: QuestionProvider {

    /// How often each kind comes up, by effective age (0 = not yet).
    static let weights: [LogicKind: Keyframes] = [
        .pattern: Keyframes([(4, 5), (7, 2), (10, 1), (14, 1)]),
        .oddOneOut: Keyframes([(4, 4), (7, 2), (10, 1.5), (14, 1)]),
        .numberSequence: Keyframes([(5.4, 0), (5.5, 1.5), (8, 3), (14, 3)]),
        .matrix: Keyframes([(6.4, 0), (6.5, 1.5), (9, 3), (14, 3)]),
        .analogy: Keyframes([(6.4, 0), (6.5, 1.5), (10, 2), (14, 2)]),
    ]

    /// Coloured shapes: `shapes[shape][colour]`, colours red, orange, yellow, green, blue, purple.
    static let shapes: [[String]] = [
        ["🔴", "🟠", "🟡", "🟢", "🔵", "🟣"],
        ["🟥", "🟧", "🟨", "🟩", "🟦", "🟪"],
        ["❤️", "🧡", "💛", "💚", "💙", "💜"],
    ]
    /// Pictures for the youngest children's patterns.
    static let pictures = ["🐶", "🐱", "🐭", "🐰", "🍎", "🍌", "🍇", "⭐", "🌙", "☀️", "🌸", "🚗"]
    /// The gap in a row or field.
    static let missing = "❓"
    /// The arrow in an analogy ("🐄 ➡️ 🥛").
    static let arrow = "➡️"

    struct Puzzle {
        let question: Question
        /// Avoids the same puzzle twice in a round.
        let key: String
    }

    let subjectID: String
    let content: LogicContent
    let phrasing: Phrasing

    func makeQuestions<R: RandomNumberGenerator>(
        count: Int,
        difficulty: Difficulty,
        recentlyCorrect: Set<String>,
        using rng: inout R
    ) -> [Question] {
        let a = difficulty.effectiveAge
        let weights: [(LogicKind, Double)] = LogicKind.allCases
            .map { ($0, max(0, Self.weights[$0]?.value(at: a) ?? 0)) }
            .filter { $0.1 > 0 }
        var questions: [Question] = []
        var keys: Set<String> = []
        var last: LogicKind?
        var attempts = 0
        while questions.count < count && attempts < count * 20 {
            attempts += 1
            // Variety: the same kind twice in a row only when nothing else fits.
            let allowed = weights.filter { $0.0 != last || weights.count == 1 }
            let kind = WeightedPick.pick(allowed, using: &rng) ?? .pattern
            guard let puzzle = make(kind, difficulty: difficulty, using: &rng), !keys.contains(puzzle.key) else { continue }
            keys.insert(puzzle.key)
            last = kind
            questions.append(puzzle.question)
        }
        return questions
    }

    /// One puzzle of a kind (nil when the content has nothing for this age).
    func make<R: RandomNumberGenerator>(_ kind: LogicKind, difficulty: Difficulty, using rng: inout R) -> Puzzle? {
        switch kind {
        case .pattern: return pattern(difficulty, using: &rng)
        case .oddOneOut: return oddOneOut(difficulty, using: &rng)
        case .numberSequence: return numberSequence(difficulty, using: &rng)
        case .matrix: return matrix(difficulty, using: &rng)
        case .analogy: return analogy(difficulty, using: &rng)
        }
    }

    // MARK: Helpers

    /// An integer in `lo...hi`, or `lo` when the range is empty (like the web's `randomInt`).
    private func randomInt<R: RandomNumberGenerator>(_ lo: Int, _ hi: Int, using rng: inout R) -> Int {
        hi <= lo ? lo : Int.random(in: lo...hi, using: &rng)
    }

    private func chance<R: RandomNumberGenerator>(_ p: Double, using rng: inout R) -> Bool {
        Double.random(in: 0..<1, using: &rng) < p
    }

    /// The right answer and up to `count - 1` different wrong ones, shuffled; each shown as a picture.
    private func choice<R: RandomNumberGenerator>(
        _ correct: String,
        wrong: [String],
        count: Int,
        using rng: inout R
    ) -> (options: [AnswerOption], correctIndex: Int) {
        var seen: Set<String> = []
        let distinct = wrong.filter { $0 != correct && seen.insert($0).inserted }
        let picked = Array(distinct.shuffled(using: &rng).prefix(max(0, count - 1)))
        let values = ([correct] + picked).shuffled(using: &rng)
        let options = values.enumerated().map { AnswerOption(id: $0.offset, text: $0.element, emoji: $0.element) }
        return (options, values.firstIndex(of: correct) ?? 0)
    }

    private func question(
        _ kind: LogicKind,
        prompt: String,
        visual: QuestionVisual?,
        format: QuestionFormat,
        explanation: String? = nil,
        spoken: String? = nil
    ) -> Question {
        Question(
            subjectID: subjectID,
            prompt: prompt,
            visual: visual,
            format: format,
            explanation: explanation,
            spoken: spoken,
            skill: kind.rawValue
        )
    }

    private static func power(_ base: Int, _ exponent: Int) -> Int {
        var result = 1
        for _ in 0..<max(0, exponent) { result *= base }
        return result
    }

    // MARK: Patterns

    /// Repeating units, longer with age; from 8 a gap in the middle; from 9 two
    /// features (shape and colour) that repeat separately.
    private func pattern<R: RandomNumberGenerator>(_ d: Difficulty, using rng: inout R) -> Puzzle? {
        let a = d.effectiveAge
        let sequence: [String]
        let pool: [String]
        if a >= 9 {
            // Shapes repeat every 2 and colours every 3 (or the other way round): both must be right.
            let (shapeEvery, colourEvery) = chance(0.5, using: &rng) ? (2, 3) : (3, 2)
            let shapes = Array([0, 1, 2].shuffled(using: &rng).prefix(shapeEvery))
            let colours = Array(Array(0..<6).shuffled(using: &rng).prefix(colourEvery))
            sequence = (0..<8).map { Self.shapes[shapes[$0 % shapeEvery]][colours[$0 % colourEvery]] }
            pool = shapes.flatMap { s in colours.map { c in Self.shapes[s][c] } }
        } else {
            let units = a < 5.5 ? ["AB"] : a < 7 ? ["AB", "ABC", "AAB", "ABB"] : ["ABC", "AABB", "ABBC", "ABCD", "AABC"]
            let unit = Array(units[randomInt(0, units.count - 1, using: &rng)])
            var letters: [Character] = []
            for letter in unit where !letters.contains(letter) { letters.append(letter) }
            let source = a < 6.5 ? Self.pictures : Self.shapes[randomInt(0, 2, using: &rng)]
            let symbols = Array(source.shuffled(using: &rng).prefix(letters.count))
            let map = Dictionary(uniqueKeysWithValues: zip(letters, symbols))
            let length = max(6, unit.count * 2 + 1)
            sequence = (0...length).map { map[unit[$0 % unit.count]] ?? "" }
            let extras = (a < 6.5 ? Self.pictures : Self.shapes.flatMap { $0 }).filter { !symbols.contains($0) }
            pool = symbols + Array(extras.prefix(2))
        }
        var gap = sequence.count - 1
        if a >= 8, chance(0.5, using: &rng) {
            gap = randomInt(2, sequence.count - 2, using: &rng)
        }
        let answer = sequence[gap]
        let shown = sequence.enumerated().map { $0.offset == gap ? Self.missing : $0.element }
        let prompt = phrasing.text(gap == sequence.count - 1 ? "logic.pattern" : "logic.patternGap")
        let options = choice(answer, wrong: pool, count: d.answerOptionCount, using: &rng)
        return Puzzle(
            question: question(
                .pattern,
                prompt: prompt,
                visual: .tiles(items: shown, columns: nil),
                format: .multipleChoice(options: options.options, correctIndex: options.correctIndex)
            ),
            key: "pattern:" + shown.joined()
        )
    }

    // MARK: Odd one out

    /// Three from one group and one from another: under 8 from a different
    /// family (fruit vs cars), then a related one (birds vs insects).
    private func oddOneOut<R: RandomNumberGenerator>(_ d: Difficulty, using rng: inout R) -> Puzzle? {
        let a = d.effectiveAge
        let groups = content.groups.filter { $0.minAge <= a + 0.5 }
        guard !groups.isEmpty else { return nil }
        let main = groups[randomInt(0, groups.count - 1, using: &rng)]
        let others = groups.filter { $0.id != main.id && (a >= 8 ? $0.family == main.family : $0.family != main.family) }
        let candidates = others.isEmpty ? groups.filter { $0.id != main.id } : others
        guard let odd = candidates.shuffled(using: &rng).first, !odd.items.isEmpty else { return nil }
        // Always three that belong together: with two, either could be "the odd one".
        let same = Array(main.items.shuffled(using: &rng).prefix(3))
        let out = odd.items[randomInt(0, odd.items.count - 1, using: &rng)]
        let values = (same + [out]).shuffled(using: &rng)
        let options = values.enumerated().map { AnswerOption(id: $0.offset, text: $0.element, emoji: $0.element) }
        return Puzzle(
            question: question(
                .oddOneOut,
                prompt: phrasing.text("logic.oddOneOut"),
                visual: nil,
                format: .multipleChoice(options: options, correctIndex: values.firstIndex(of: out) ?? 0),
                explanation: phrasing.text("logic.oddOneOut.explain", ["item": main.label])
            ),
            key: "odd:" + same.sorted().joined() + out
        )
    }

    // MARK: Number sequences

    /// Steps get bigger, then go down, double, alternate, grow, and finally squares and sums.
    private func numberSequence<R: RandomNumberGenerator>(_ d: Difficulty, using rng: inout R) -> Puzzle? {
        let a = d.effectiveAge
        func up(_ start: Int, _ step: Int, _ n: Int = 6) -> [Int] {
            (0..<n).map { start + $0 * step }
        }

        // The rules of each age band, picked by index (the web keeps them as closures).
        let band: Int
        let ruleCount: Int
        if a < 7 {
            band = 0
            ruleCount = a >= 6.5 ? 5 : 3
        } else if a < 8.5 {
            band = 1
            ruleCount = 3
        } else if a < 10 {
            band = 2
            ruleCount = 3
        } else {
            band = 3
            ruleCount = 5
        }
        let rule = randomInt(0, ruleCount - 1, using: &rng)

        var seq: [Int] = []
        switch (band, rule) {
        case (0, 0):
            seq = up(randomInt(1, 5, using: &rng), 1)
        case (0, 1):
            seq = up(randomInt(0, 4, using: &rng) * 2, 2)
        case (0, 2):
            seq = up(5, 5)
        case (0, 3):
            seq = up(10, 10)
        case (0, _):
            seq = up(randomInt(12, 20, using: &rng), -1)

        case (1, 0):
            let start = randomInt(1, 9, using: &rng)
            let step = randomInt(3, 5, using: &rng)
            seq = up(start, step)
        case (1, 1):
            let start = randomInt(25, 40, using: &rng)
            let step = randomInt(2, 5, using: &rng)
            seq = up(start, -step)
        case (1, _):
            seq = up(randomInt(1, 9, using: &rng) * 10, 10)

        case (2, 0):
            // Doubling.
            let s = randomInt(1, 5, using: &rng)
            seq = (0..<6).map { s * Self.power(2, $0) }
        case (2, 1):
            // Growing steps: +0, +1, +2, …
            var v = randomInt(1, 5, using: &rng)
            for i in 0..<6 {
                v += i
                seq.append(v)
            }
        case (2, _):
            // Alternating: up x, down y.
            let x = randomInt(2, 5, using: &rng)
            let y = randomInt(1, 3, using: &rng)
            var v = randomInt(1, 10, using: &rng)
            for i in 0..<7 {
                if i > 0 { v += i % 2 == 1 ? x : -y }
                seq.append(v)
            }

        case (_, 0):
            // Squares.
            let s = randomInt(1, 3, using: &rng)
            seq = (0..<6).map { ($0 + s) * ($0 + s) }
        case (_, 1):
            // Times three.
            let s = randomInt(1, 3, using: &rng)
            seq = (0..<6).map { s * Self.power(3, $0) }
        case (_, 2):
            // Each the sum of the two before.
            let first = randomInt(1, 3, using: &rng)
            seq = [first, first + randomInt(1, 3, using: &rng)]
            while seq.count < 7 { seq.append(seq[seq.count - 1] + seq[seq.count - 2]) }
        case (_, 3):
            // Double and one more.
            var v = randomInt(1, 4, using: &rng)
            for i in 0..<6 {
                if i > 0 { v = v * 2 + 1 }
                seq.append(v)
            }
        default:
            // Halving.
            let big = randomInt(2, 6, using: &rng) * 64
            seq = (0..<6).map { big / Self.power(2, $0) }
        }

        guard seq.count >= 3, !seq.contains(where: { $0 < 0 || $0 > 9999 }) else { return nil }
        var gap = seq.count - 1
        if a >= 8.5, chance(0.35, using: &rng) {
            gap = randomInt(1, seq.count - 2, using: &rng)
        }
        let answer = seq[gap]
        let text = seq.enumerated().map { $0.offset == gap ? "?" : String($0.element) }.joined(separator: ", ")
        let difference = abs(seq[seq.count - 1] - seq[seq.count - 2])
        let step = difference == 0 ? 1 : difference
        let wrong = [answer + 1, answer - 1, answer + step, answer - step, answer + 2, answer + 10]
            .filter { $0 >= 0 && $0 != answer }
            .map { String($0) }

        let format: QuestionFormat
        if d.maths.usesNumberPad {
            format = .numberEntry(answer: answer)
        } else {
            let c = choice(String(answer), wrong: wrong, count: d.answerOptionCount, using: &rng)
            format = .multipleChoice(options: c.options.map { AnswerOption(id: $0.id, text: $0.text) }, correctIndex: c.correctIndex)
        }
        let prompt = phrasing.text(gap == seq.count - 1 ? "logic.numbers" : "logic.numbersGap")
        return Puzzle(
            question: question(
                .numberSequence,
                prompt: prompt,
                visual: .equation(text),
                format: format,
                spoken: prompt + " " + text.replacingOccurrences(of: "?", with: "…")
            ),
            key: "numbers:" + text
        )
    }

    // MARK: Matrices

    /// A 3×3 field with one picture missing. Under 8: each row one shape, each
    /// column one colour. Under 10: every row and column has each shape and each
    /// colour once (a Latin square), and the gap can be anywhere. From 10: also
    /// one, two or three of them, growing along the row.
    private func matrix<R: RandomNumberGenerator>(_ d: Difficulty, using rng: inout R) -> Puzzle? {
        let a = d.effectiveAge
        let shapes = [0, 1, 2].shuffled(using: &rng)
        let colours = Array(Array(0..<6).shuffled(using: &rng).prefix(3))
        let counted = a >= 10
        let latin = a >= 8

        func shapeAt(_ r: Int, _ c: Int) -> Int { latin ? shapes[(r + c) % 3] : shapes[r] }
        func colourAt(_ r: Int, _ c: Int) -> Int { latin ? colours[(r + 2 * c) % 3] : colours[c] }
        func picture(_ shape: Int, _ colour: Int, _ n: Int) -> String {
            String(repeating: Self.shapes[shape][colour], count: n)
        }

        let cells = (0..<9).map { i in picture(shapeAt(i / 3, i % 3), colourAt(i / 3, i % 3), counted ? i % 3 + 1 : 1) }
        let gap = latin ? randomInt(0, 8, using: &rng) : 8
        let answer = cells[gap]
        let r = gap / 3
        let c = gap % 3
        let s0 = shapeAt(r, c)
        let c0 = colourAt(r, c)
        let n = counted ? c + 1 : 1
        var wrong = shapes.filter { $0 != s0 }.map { picture($0, c0, n) }
        wrong += colours.filter { $0 != c0 }.map { picture(s0, $0, n) }
        if counted {
            wrong += [1, 2, 3].filter { $0 != n }.map { picture(s0, c0, $0) }
        }
        let shuffledWrong = wrong.shuffled(using: &rng)
        let options = choice(answer, wrong: shuffledWrong, count: d.answerOptionCount, using: &rng)
        let shown = cells.enumerated().map { $0.offset == gap ? Self.missing : $0.element }
        return Puzzle(
            question: question(
                .matrix,
                prompt: phrasing.text("logic.matrix"),
                visual: .tiles(items: shown, columns: 3),
                format: .multipleChoice(options: options.options, correctIndex: options.correctIndex)
            ),
            key: "matrix:" + cells.joined() + ":" + String(gap)
        )
    }

    // MARK: Analogies

    private func analogy<R: RandomNumberGenerator>(_ d: Difficulty, using rng: inout R) -> Puzzle? {
        let pool = content.analogies.filter { $0.minAge <= d.effectiveAge + 0.5 }
        guard !pool.isEmpty else { return nil }
        let item = pool[randomInt(0, pool.count - 1, using: &rng)]
        let options = choice(item.answer, wrong: item.wrong, count: d.answerOptionCount, using: &rng)
        return Puzzle(
            question: question(
                .analogy,
                prompt: phrasing.text("logic.analogy"),
                visual: .tiles(items: [item.a, Self.arrow, item.b, item.c, Self.arrow, Self.missing], columns: 3),
                format: .multipleChoice(options: options.options, correctIndex: options.correctIndex),
                explanation: item.explanation
            ),
            key: "analogy:" + item.a + item.c
        )
    }
}
