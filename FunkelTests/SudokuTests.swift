import SwiftData
import XCTest
@testable import Funkel

/// Mirrors the Sudoku part of web/tests/puzzles.test.ts.
@MainActor
final class SudokuTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testGrowsFromPicture4x4ToClassic9x9WithAge() {
        XCTAssertEqual(SudokuLevel.forAge(4).size, 4)
        XCTAssertTrue(SudokuLevel.forAge(4).pictures)
        XCTAssertTrue(SudokuLevel.forAge(5).pictures)
        XCTAssertEqual(SudokuLevel.forAge(6).size, 4)
        XCTAssertFalse(SudokuLevel.forAge(6).pictures)
        XCTAssertEqual(SudokuLevel.forAge(8).size, 6)
        XCTAssertEqual(SudokuLevel.forAge(8).boxRows, 2)
        XCTAssertEqual(SudokuLevel.forAge(8).boxCols, 3)
        XCTAssertEqual(SudokuLevel.forAge(10).size, 9)
        XCTAssertGreaterThan(SudokuLevel.forAge(14).blanks, SudokuLevel.forAge(10).blanks)
        // Same table as the web app.
        XCTAssertEqual((4...14).map { SudokuLevel.forAge($0).blanks }, [5, 7, 9, 11, 14, 19, 36, 42, 48, 52, 52])
        XCTAssertEqual((4...14).map { SudokuLevel.forAge($0).stars }, [3, 3, 4, 4, 6, 6, 8, 8, 10, 10, 10])
        XCTAssertEqual(SudokuLevel.forAge(4).symbol(1), "🍎")
        XCTAssertEqual(SudokuLevel.forAge(10).symbol(7), "7")
    }

    func testPeersShareARowColumnOrBox() {
        let level = SudokuLevel.forAge(10)
        XCTAssertEqual(level.peers(of: 0).count, 20)
        XCTAssertFalse(level.peers(of: 0).contains(0))
        XCTAssertTrue(level.peers(of: 0).contains(20))   // same box
        XCTAssertFalse(level.peers(of: 0).contains(30))  // row 3, column 3
        XCTAssertEqual(SudokuLevel.forAge(8).peers(of: 0).count, 5 + 5 + 2)
    }

    func testMakesValidPuzzlesWithExactlyOneSolution() {
        var rng = SeededGenerator(seed: 21)
        for age in [4, 6, 8, 9, 10, 13] {
            let level = SudokuLevel.forAge(age)
            for _ in 0..<(level.size == 9 ? 2 : 10) {
                let sudoku = Sudoku.make(level, using: &rng)
                XCTAssertEqual(sudoku.solution.count, level.size * level.size)
                for (cell, value) in sudoku.solution.enumerated() {
                    XCTAssertTrue((1...level.size).contains(value))
                    for peer in level.peers(of: cell) {
                        XCTAssertNotEqual(sudoku.solution[peer], value, "age \(age), cell \(cell)")
                    }
                }
                let blanks = sudoku.given.filter { !$0 }.count
                XCTAssertGreaterThanOrEqual(blanks, level.size == 9 ? level.blanks - 6 : level.blanks, "age \(age)")
                XCTAssertEqual(Sudoku.countSolutions(level, puzzle: sudoku.startValues), 1, "age \(age)")
            }
        }
    }

    func testTheSameSeedMakesTheSamePuzzle() {
        var a = SeededGenerator(seed: 7)
        var b = SeededGenerator(seed: 7)
        XCTAssertEqual(Sudoku.make(.forAge(8), using: &a), Sudoku.make(.forAge(8), using: &b))
    }

    func testRewardsSolvedPuzzlesALittleLessWithHelp() {
        let level = SudokuLevel.forAge(10)
        XCTAssertEqual(level.stars(mistakes: 0, hints: 0), level.stars)
        XCTAssertEqual(level.stars(mistakes: 3, hints: 1), level.stars - 2)
        XCTAssertEqual(level.stars(mistakes: 30, hints: 30), 1)
    }

    func testDifficultyShiftsTheAge() {
        XCTAssertEqual(SudokuDifficulty.hard.age(for: 5), 7)
        XCTAssertEqual(SudokuDifficulty.easy.age(for: 5), 4)
        XCTAssertEqual(SudokuDifficulty.hard.age(for: 13), 14)
        XCTAssertEqual(SudokuDifficulty.normal.age(for: 9), 9)
    }

    // MARK: Playing

    func testWrongEntriesWobbleAndHintsFillACell() throws {
        var rng = SeededGenerator(seed: 3)
        let game = SudokuGame(age: 6, using: &rng)
        let cell = try XCTUnwrap(game.selected)
        XCTAssertEqual(game.values[cell], 0)
        let answer = game.puzzle.solution[cell]
        let wrong = answer % game.level.size + 1

        XCTAssertEqual(game.enter(wrong), .wrong)
        XCTAssertEqual(game.values[cell], 0, "a mistake never stays on the board")
        XCTAssertEqual(game.mistakes, 1)

        XCTAssertEqual(game.enter(answer), .placed)
        XCTAssertEqual(game.values[cell], answer)
        XCTAssertNil(game.selected)
        XCTAssertEqual(game.enter(answer), .ignored)

        // A given cell can be selected but not changed.
        let given = try XCTUnwrap(game.puzzle.given.firstIndex(of: true))
        game.select(given)
        XCTAssertEqual(game.enter(1), .ignored)
        XCTAssertEqual(game.related, Set(game.level.peers(of: given)))

        XCTAssertEqual(game.hint(), .placed)
        XCTAssertEqual(game.hints, 1)
    }

    func testFillingTheLastCellSolvesThePuzzle() {
        var rng = SeededGenerator(seed: 5)
        let game = SudokuGame(age: 4, using: &rng)
        let blanks = game.values.filter { $0 == 0 }.count
        var last = SudokuGame.Outcome.ignored
        while !game.isSolved {
            last = game.hint()
        }
        XCTAssertEqual(game.hints, blanks)
        XCTAssertEqual(last, .solved(stars: game.level.stars(mistakes: 0, hints: blanks)))
        XCTAssertEqual(game.values, game.puzzle.solution)
        XCTAssertEqual(game.hint(), .ignored)
    }

    // MARK: Profile

    func testSettingsAreStoredUnderTheWebNames() {
        let profile = ChildProfile(name: "Lena", age: 5)
        XCTAssertTrue(profile.sudokuEnabled)
        XCTAssertEqual(profile.sudokuDifficulty, .normal)

        var settings = ProfileSettings(profile: profile)
        settings.sudokuEnabled = false
        settings.sudokuDifficulty = .hard
        settings.apply(to: profile)

        XCTAssertEqual(profile.webField("sudokuEnabled", as: Bool.self), false)
        XCTAssertEqual(profile.webField("sudokuDifficulty", as: String.self), "hard")
        XCTAssertEqual(profile.sudokuAge, 7)
        XCTAssertEqual(ProfileSettings(profile: profile).sudokuDifficulty, .hard)
    }

    func testRecordingASolvedSudoku() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Lena", age: 5)
        context.insert(profile)
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 10))!

        ProgressRecorder(context: context).recordSudoku(stars: 3, for: profile, at: day, calendar: calendar)
        XCTAssertEqual(profile.totalStars, 3)
        XCTAssertEqual(profile.walletStars, 3)
        XCTAssertEqual(profile.currentStreak, 1)
        XCTAssertEqual(profile.sudokusSolved, 1)
        XCTAssertTrue(profile.rounds.isEmpty, "Sudokus don't show up as learning rounds")

        ProgressRecorder(context: context).recordSudoku(stars: 2, for: profile, at: day.addingTimeInterval(86_400), calendar: calendar)
        XCTAssertEqual(profile.sudokusSolved, 2)
        XCTAssertEqual(profile.currentStreak, 2)
        let progress = try XCTUnwrap(profile.subjectProgress(for: "sudoku", language: "puzzle"))
        XCTAssertEqual(progress.stars, 5)
        XCTAssertEqual(progress.questionsAnswered, 0)
    }

    func testSudokuProgressAndSettingsRoundTripThroughABackup() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Emil", age: 10)
        context.insert(profile)
        profile.sudokuEnabled = false
        profile.sudokuDifficulty = .easy
        ProgressRecorder(context: context).recordSudoku(stars: 8, for: profile, calendar: calendar)

        let json = Backup.webProfile(profile, calendar: calendar)
        XCTAssertEqual(json["sudokuEnabled"] as? Bool, false)
        XCTAssertEqual(json["sudokuDifficulty"] as? String, "easy")
        let entry = try XCTUnwrap((json["progress"] as? [String: Any])?["puzzle/sudoku"] as? [String: Any])
        XCTAssertEqual(Backup.int(entry["roundsPlayed"]), 1)
        XCTAssertEqual(Backup.int(entry["stars"]), 8)

        let data = try Backup.export([profile], calendar: calendar)
        guard case .success(let contents) = Backup.read(data) else { return XCTFail("unreadable backup") }
        let restored = try XCTUnwrap(Backup.restore(contents, into: try makeContext(), calendar: calendar).first)
        XCTAssertFalse(restored.sudokuEnabled)
        XCTAssertEqual(restored.sudokuDifficulty, .easy)
        XCTAssertEqual(restored.sudokusSolved, 1)
        XCTAssertEqual(restored.totalStars, 8)
    }

    func testAWebBackupWithoutSudokuFieldsUsesTheDefaults() throws {
        let profile = Backup.makeProfile(from: ["id": "x", "name": "Mia", "age": 8], in: try makeContext())
        XCTAssertTrue(profile.sudokuEnabled)
        XCTAssertEqual(profile.sudokuDifficulty, .normal)
        XCTAssertEqual(profile.sudokusSolved, 0)
    }
}
