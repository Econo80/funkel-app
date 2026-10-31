import Foundation

/// Sudoku for children: picture 4×4 grids for the youngest, up to classic 9×9.
/// Every puzzle has exactly one solution. Mirrors web/src/domain/sudoku.ts.
struct SudokuLevel: Equatable {
    /// 4, 6 or 9.
    let size: Int
    /// Box shape: rows × columns (6×6 uses 2×3 boxes).
    let boxRows: Int
    let boxCols: Int
    /// How many cells start empty.
    let blanks: Int
    /// Pictures instead of numbers, for children who don't read numbers yet.
    let pictures: Bool
    /// Stars for a solved puzzle without help.
    let stars: Int

    static let pictureSymbols = ["🍎", "🐟", "⭐", "🌼"]

    /// Ages 4–5 pictures 4×4, 6–7 numbers 4×4, 8–9 6×6, from 10 the classic 9×9.
    static func forAge(_ age: Int) -> SudokuLevel {
        switch age {
        case ..<5: SudokuLevel(size: 4, boxRows: 2, boxCols: 2, blanks: 5, pictures: true, stars: 3)
        case 5: SudokuLevel(size: 4, boxRows: 2, boxCols: 2, blanks: 7, pictures: true, stars: 3)
        case 6: SudokuLevel(size: 4, boxRows: 2, boxCols: 2, blanks: 9, pictures: false, stars: 4)
        case 7: SudokuLevel(size: 4, boxRows: 2, boxCols: 2, blanks: 11, pictures: false, stars: 4)
        case 8: SudokuLevel(size: 6, boxRows: 2, boxCols: 3, blanks: 14, pictures: false, stars: 6)
        case 9: SudokuLevel(size: 6, boxRows: 2, boxCols: 3, blanks: 19, pictures: false, stars: 6)
        case 10, 11: SudokuLevel(size: 9, boxRows: 3, boxCols: 3, blanks: age < 11 ? 36 : 42, pictures: false, stars: 8)
        default: SudokuLevel(size: 9, boxRows: 3, boxCols: 3, blanks: age < 13 ? 48 : 52, pictures: false, stars: 10)
        }
    }

    var cellCount: Int { size * size }

    /// What a value looks like on the board and the keys: 🍎 or "3".
    func symbol(_ value: Int) -> String {
        pictures ? Self.pictureSymbols[value - 1] : String(value)
    }

    /// The cells that share a row, column or box with `cell` (not the cell itself).
    func peers(of cell: Int) -> [Int] {
        let row = cell / size, col = cell % size
        let r0 = row - row % boxRows, c0 = col - col % boxCols
        var result = Set<Int>()
        for i in 0..<size {
            result.insert(row * size + i)
            result.insert(i * size + col)
        }
        for r in r0..<(r0 + boxRows) {
            for c in c0..<(c0 + boxCols) { result.insert(r * size + c) }
        }
        result.remove(cell)
        return result.sorted()
    }

    /// Stars for a solved puzzle: one less per hint and per three mistakes, at least one.
    func stars(mistakes: Int, hints: Int) -> Int {
        max(1, stars - hints - mistakes / 3)
    }
}

/// The grown-up setting that shifts the Sudoku age, stored under the web app's names.
enum SudokuDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy, normal, hard
    var id: String { rawValue }

    /// Years added to the child's age, like the web app's game difficulty.
    var ageOffset: Int {
        switch self {
        case .easy: -2
        case .normal: 0
        case .hard: 2
        }
    }

    /// The age Sudokus are made for: the child's age, shifted by the setting.
    func age(for childAge: Int) -> Int {
        (childAge + ageOffset).clamped(to: DifficultyTuning.ageRange)
    }
}

struct Sudoku: Equatable {
    let level: SudokuLevel
    /// Values 1…size, row by row.
    let solution: [Int]
    /// Cells shown from the start.
    let given: [Bool]

    /// The board at the start: given cells filled, the rest 0.
    var startValues: [Int] {
        zip(solution, given).map { $1 ? $0 : 0 }
    }

    /// A new puzzle with a unique solution and (as close as possible to) the level's number of blanks.
    static func make<R: RandomNumberGenerator>(_ level: SudokuLevel, using rng: inout R) -> Sudoku {
        let solver = SudokuSolver(level: level)
        var solution = [Int](repeating: 0, count: level.cellCount)
        _ = solver.solve(&solution, limit: 1, rng: &rng)

        var puzzle = solution
        var blanks = 0
        for cell in Array(0..<level.cellCount).shuffled(using: &rng) {
            if blanks >= level.blanks { break }
            let keep = puzzle[cell]
            puzzle[cell] = 0
            var copy = puzzle
            if solver.solve(&copy, limit: 2) == 1 {
                blanks += 1
            } else {
                puzzle[cell] = keep
            }
        }
        return Sudoku(level: level, solution: solution, given: puzzle.map { $0 != 0 })
    }

    /// How many solutions `puzzle` (0 = empty) has, counting at most `limit`.
    static func countSolutions(_ level: SudokuLevel, puzzle: [Int], limit: Int = 2) -> Int {
        var grid = puzzle
        return SudokuSolver(level: level).solve(&grid, limit: limit)
    }
}

/// Backtracking that always tries the empty cell with the fewest options first.
private struct SudokuSolver {
    let level: SudokuLevel
    let peers: [[Int]]

    init(level: SudokuLevel) {
        self.level = level
        peers = (0..<level.cellCount).map(level.peers(of:))
    }

    func candidates(_ grid: [Int], _ cell: Int) -> [Int] {
        var used = [Bool](repeating: false, count: level.size + 1)
        for peer in peers[cell] { used[grid[peer]] = true }
        return (1...level.size).filter { !used[$0] }
    }

    /// Fills empty cells without randomness (for counting solutions).
    func solve(_ grid: inout [Int], limit: Int) -> Int {
        var none: SystemRandomNumberGenerator? = nil
        return search(&grid, limit: limit, rng: &none)
    }

    func solve<R: RandomNumberGenerator>(_ grid: inout [Int], limit: Int, rng: inout R) -> Int {
        var optional: R? = rng
        defer { rng = optional! }
        return search(&grid, limit: limit, rng: &optional)
    }

    /// Fills empty (0) cells; with `rng` in random order. Stops after `limit`
    /// solutions and leaves the grid filled with the last one; returns how many it found.
    private func search<R: RandomNumberGenerator>(_ grid: inout [Int], limit: Int, rng: inout R?) -> Int {
        var best = -1
        var bestOptions: [Int] = []
        for cell in grid.indices where grid[cell] == 0 {
            let options = candidates(grid, cell)
            if options.isEmpty { return 0 }
            if best == -1 || options.count < bestOptions.count {
                best = cell
                bestOptions = options
            }
            if options.count == 1 { break }
        }
        if best == -1 { return 1 }

        if rng != nil { bestOptions.shuffle(using: &rng!) }
        var found = 0
        for value in bestOptions {
            grid[best] = value
            found += search(&grid, limit: limit - found, rng: &rng)
            if found >= limit { return found }   // leave the grid filled when generating
        }
        grid[best] = 0
        return found
    }
}
