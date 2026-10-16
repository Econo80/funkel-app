import Foundation
import SwiftData

/// Grown-up actions that change or remove a profile's data.
enum ProfileMaintenance {

    /// Clears stars, streaks, per-subject progress, history and adaptivity.
    /// Name, age and settings stay.
    static func resetProgress(of profile: ChildProfile, in context: ModelContext) {
        let progress = profile.progress
        let rounds = profile.rounds
        profile.progress.removeAll()
        profile.rounds.removeAll()
        progress.forEach { context.delete($0) }
        rounds.forEach { context.delete($0) }

        profile.totalStars = 0
        profile.currentStreak = 0
        profile.longestStreak = 0
        profile.lastPlayedDay = nil
        profile.difficultyAdjustment = 0
        try? context.save()
    }

    /// Deletes the profile; its progress and history go with it (cascade).
    static func delete(_ profile: ChildProfile, in context: ModelContext) {
        context.delete(profile)
        try? context.save()
    }
}
