import Foundation
import SwiftData

/// Grown-up actions that change or remove a profile's data.
enum ProfileMaintenance {

    /// Clears stars (lifetime and to spend), streaks, per-subject progress and
    /// levels, history, and the web app's game and garden progress kept for
    /// backups. Name, age and settings stay.
    static func resetProgress(of profile: ChildProfile, in context: ModelContext) {
        let progress = profile.progress
        let rounds = profile.rounds
        profile.progress.removeAll()
        profile.rounds.removeAll()
        progress.forEach { context.delete($0) }
        rounds.forEach { context.delete($0) }

        profile.totalStars = 0
        profile.walletStars = 0
        profile.giftStars = 0
        profile.currentStreak = 0
        profile.longestStreak = 0
        profile.lastPlayedDay = nil
        profile.difficultyAdjustment = 0
        profile.backupExtras = BackupExtras.withoutProgress(profile.backupExtras)
        try? context.save()
    }

    /// Deletes the profile; its progress and history go with it (cascade).
    static func delete(_ profile: ChildProfile, in context: ModelContext) {
        context.delete(profile)
        try? context.save()
    }

    // MARK: Levels

    /// A grown-up sets a subject's level directly (years above/below the real age,
    /// in half years). Only this subject changes; stars, streaks and history stay.
    /// Adaptivity carries on from here.
    static func setSubjectAdjustment(_ adjustment: Double, subjectID: String, language: String, of profile: ChildProfile, in context: ModelContext) {
        let progress = profile.subjectProgress(for: subjectID, language: language) ?? {
            let progress = SubjectProgress(subjectID: subjectID, languageCode: language)
            context.insert(progress)
            profile.progress.append(progress)
            return progress
        }()
        progress.adjustment = ((adjustment * 2).rounded() / 2).clamped(to: DifficultyScale.adjustmentRange)
        progress.perfectRounds = 0
    }

    // MARK: Gifts

    static let giftChoices = [10, 25, 50, 100]
    static let giftMax = 500

    /// A grown-up gives stars to spend. Lifetime stars stay learning stars.
    static func giveStars(_ amount: Int, to profile: ChildProfile) {
        let stars = amount.clamped(to: 0...giftMax)
        guard stars > 0 else { return }
        profile.walletStars += stars
        profile.giftStars += stars
    }

    // MARK: Upgrading old data

    /// Profiles saved before the wallet existed can spend what they have earned.
    static func prepareWallets(in context: ModelContext) {
        guard let profiles = try? context.fetch(FetchDescriptor<ChildProfile>()) else { return }
        var changed = false
        for profile in profiles where !profile.walletReady {
            profile.walletStars = profile.totalStars
            profile.walletReady = true
            changed = true
        }
        if changed { try? context.save() }
    }
}
