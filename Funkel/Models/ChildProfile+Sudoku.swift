import Foundation
import SwiftData

/// Sudoku settings and progress, the way the web app keeps them
/// (web/src/domain/profile.ts): settings as web fields, solved puzzles as the
/// progress entry "puzzle/sudoku".
extension ChildProfile {
    static let sudokuSubjectID = "sudoku"
    static let sudokuLanguageCode = "puzzle"

    /// Sudoku card on the home screen (default on).
    var sudokuEnabled: Bool {
        get { webField("sudokuEnabled") ?? true }
        set { setWebField("sudokuEnabled", newValue) }
    }

    var sudokuDifficulty: SudokuDifficulty {
        get { webField("sudokuDifficulty", as: String.self).flatMap(SudokuDifficulty.init(rawValue:)) ?? .normal }
        set { setWebField("sudokuDifficulty", newValue.rawValue) }
    }

    /// The age Sudokus are made for: the child's age, shifted by the grown-up setting.
    var sudokuAge: Int { sudokuDifficulty.age(for: age) }

    var sudokusSolved: Int {
        subjectProgress(for: Self.sudokuSubjectID, language: Self.sudokuLanguageCode)?.roundsPlayed ?? 0
    }
}

extension ProgressRecorder {
    /// A solved Sudoku: stars into the total and the wallet, and it counts for the streak.
    func recordSudoku(stars: Int, for profile: ChildProfile, at now: Date = .now, calendar: Calendar = .current) {
        profile.totalStars += stars
        profile.walletStars += stars

        let streak = StreakCalculator.update(
            current: profile.currentStreak,
            longest: profile.longestStreak,
            lastPlayedDay: profile.lastPlayedDay,
            playedAt: now,
            calendar: calendar
        )
        profile.currentStreak = streak.current
        profile.longestStreak = streak.longest
        profile.lastPlayedDay = streak.lastPlayedDay

        let progress: SubjectProgress
        if let existing = profile.subjectProgress(for: ChildProfile.sudokuSubjectID, language: ChildProfile.sudokuLanguageCode) {
            progress = existing
        } else {
            progress = SubjectProgress(subjectID: ChildProfile.sudokuSubjectID, languageCode: ChildProfile.sudokuLanguageCode)
            context.insert(progress)
            profile.progress.append(progress)
        }
        progress.roundsPlayed += 1
        progress.stars += stars
        progress.lastPlayed = now

        try? context.save()
    }
}
