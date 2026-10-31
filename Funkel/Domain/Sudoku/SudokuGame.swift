import Foundation
import Observation

/// One Sudoku being played. A wrong entry is counted but never placed, so
/// mistakes never stay on the board (web/src/ui/Sudoku.tsx).
@Observable
final class SudokuGame {
    enum Outcome: Equatable {
        /// Nothing happened (no empty cell selected, or already solved).
        case ignored
        case placed
        case wrong
        /// The last cell was filled; stars earned.
        case solved(stars: Int)
    }

    private(set) var puzzle: Sudoku
    /// The board: 0 = empty.
    private(set) var values: [Int]
    var selected: Int?
    private(set) var mistakes = 0
    private(set) var hints = 0
    /// Set once solved.
    private(set) var earned: Int?

    var level: SudokuLevel { puzzle.level }
    var isSolved: Bool { earned != nil }

    init(_ puzzle: Sudoku) {
        self.puzzle = puzzle
        values = puzzle.startValues
        selected = values.firstIndex(of: 0)
    }

    convenience init<R: RandomNumberGenerator>(age: Int, using rng: inout R) {
        self.init(Sudoku.make(.forAge(age), using: &rng))
    }

    /// Cells sharing a row, column or box with the selected cell.
    var related: Set<Int> {
        selected.map { Set(level.peers(of: $0)) } ?? []
    }

    /// The selected cell's value (0 when empty or nothing is selected).
    var selectedValue: Int {
        selected.map { values[$0] } ?? 0
    }

    /// How many of `value` are still missing on the board.
    func remaining(_ value: Int) -> Int {
        level.size - values.filter { $0 == value }.count
    }

    func isGiven(_ cell: Int) -> Bool { puzzle.given[cell] }

    func select(_ cell: Int) {
        guard !isSolved else { return }
        selected = cell
    }

    func enter(_ value: Int) -> Outcome {
        guard let cell = selected, values[cell] == 0, !isSolved else { return .ignored }
        if puzzle.solution[cell] == value { return fill(cell) }
        mistakes += 1
        return .wrong
    }

    /// Fills the selected empty cell (or the first empty one) with its answer.
    func hint() -> Outcome {
        guard !isSolved else { return .ignored }
        let cell = selected.flatMap { values[$0] == 0 ? $0 : nil } ?? values.firstIndex(of: 0)
        guard let cell else { return .ignored }
        hints += 1
        return fill(cell)
    }

    private func fill(_ cell: Int) -> Outcome {
        values[cell] = puzzle.solution[cell]
        selected = nil
        guard !values.contains(0) else { return .placed }
        let stars = level.stars(mistakes: mistakes, hints: hints)
        earned = stars
        return .solved(stars: stars)
    }
}
