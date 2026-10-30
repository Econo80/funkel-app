import Foundation
import SwiftData

/// The result of a finished round, before it is saved.
struct RoundOutcome: Equatable {
    let subjectID: String
    let languageCode: String
    let correct: Int
    let total: Int
    let correctContentIDs: [String]
    let effectiveAge: Double
}

/// What the summary screen shows after saving.
struct RoundSummary: Equatable {
    let correct: Int
    let total: Int
    let starsEarned: Int
    let streak: Int
    let streakGrew: Bool
    /// A run of perfect rounds made this subject harder.
    var levelUp = false

    var score: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

/// Applies a round's outcome to a profile: stars (lifetime and to spend),
/// streak, per-subject progress and level, and history.
struct ProgressRecorder {
    static let recentContentLimit = 40

    let context: ModelContext

    @discardableResult
    func record(_ outcome: RoundOutcome, for profile: ChildProfile, at now: Date = .now, calendar: Calendar = .current) -> RoundSummary {
        // One star per correct answer.
        let stars = outcome.correct
        profile.totalStars += stars
        profile.walletStars += stars

        let previousStreak = profile.currentStreak
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

        let level = DifficultyScale.nextAdaptivity(
            profile.adaptivity(for: outcome.subjectID, language: outcome.languageCode),
            correct: outcome.correct,
            total: outcome.total
        )

        let progress = profile.subjectProgress(for: outcome.subjectID, language: outcome.languageCode)
            ?? makeProgress(for: outcome, profile: profile)
        progress.roundsPlayed += 1
        progress.questionsAnswered += outcome.total
        progress.correctAnswers += outcome.correct
        progress.stars += stars
        progress.lastPlayed = now
        progress.recentCorrectContentIDs = Array((progress.recentCorrectContentIDs + outcome.correctContentIDs).suffix(Self.recentContentLimit))
        progress.adjustment = level.adaptivity.adjustment
        progress.perfectRounds = level.adaptivity.perfectRounds

        let record = RoundRecord(
            date: now,
            subjectID: outcome.subjectID,
            languageCode: outcome.languageCode,
            correct: outcome.correct,
            total: outcome.total,
            starsEarned: stars,
            effectiveAge: outcome.effectiveAge
        )
        context.insert(record)
        profile.rounds.append(record)

        try? context.save()

        return RoundSummary(
            correct: outcome.correct,
            total: outcome.total,
            starsEarned: stars,
            streak: streak.current,
            streakGrew: streak.current > previousStreak,
            levelUp: level.boosted
        )
    }

    private func makeProgress(for outcome: RoundOutcome, profile: ChildProfile) -> SubjectProgress {
        let progress = SubjectProgress(subjectID: outcome.subjectID, languageCode: outcome.languageCode)
        context.insert(progress)
        profile.progress.append(progress)
        return progress
    }
}
