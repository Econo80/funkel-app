import Foundation
import SwiftData

/// A child using the app. Only a first name and age are stored, on device.
@Model
final class ChildProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var age: Int
    /// Key into `Palette.avatarColors`.
    var avatarColor: String
    /// Content language code, e.g. "de". Independent of the device UI language.
    var learningLanguage: String
    /// Profile-wide offset older versions used for every subject; subjects
    /// without their own level start from it (PLAN.md §5.4).
    var difficultyAdjustment: Double
    /// Empty means "all subjects the learning language offers".
    var enabledSubjectIDs: [String]
    var roundLength: Int
    var soundEnabled: Bool
    var readAloudEnabled: Bool
    var hapticsEnabled: Bool
    var gentleTimerEnabled: Bool
    /// Lifetime stars: an achievement, never goes down (except a grown-up reset).
    var totalStars: Int
    /// Stars to spend (play corner, garden). Learning and grown-up gifts add to it.
    var walletStars: Int = 0
    /// Stars a grown-up gave that the child hasn't seen yet (thanked for on the home screen).
    var giftStars: Int = 0
    /// False for profiles saved before the wallet existed; set once their wallet is filled.
    var walletReady: Bool = false
    /// Everything the web app keeps that this app doesn't use yet (garden,
    /// farm, games, Sudoku …), as JSON, so backups round-trip without losses.
    var backupExtras: Data? = nil
    var currentStreak: Int
    var longestStreak: Int
    var lastPlayedDay: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SubjectProgress.profile)
    var progress: [SubjectProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \RoundRecord.profile)
    var rounds: [RoundRecord] = []

    init(
        name: String,
        age: Int,
        avatarColor: String = "sun",
        learningLanguage: String = "de",
        roundLength: Int = ProfileDefaults.roundLength
    ) {
        self.id = UUID()
        self.name = name
        self.age = age.clamped(to: DifficultyTuning.ageRange)
        self.avatarColor = avatarColor
        self.learningLanguage = learningLanguage
        self.difficultyAdjustment = 0
        self.enabledSubjectIDs = []
        self.roundLength = roundLength.clamped(to: ProfileDefaults.roundLengthRange)
        self.soundEnabled = true
        self.readAloudEnabled = age < 7
        self.hapticsEnabled = true
        self.gentleTimerEnabled = false
        self.totalStars = 0
        self.walletStars = 0
        self.giftStars = 0
        self.walletReady = true
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastPlayedDay = nil
        self.createdAt = .now
    }
}

enum ProfileDefaults {
    static let roundLength = 10
    static let roundLengthRange = 5...20
}

extension ChildProfile {
    /// Each subject keeps its own level; subjects without one start from the
    /// profile-wide adjustment that older versions shared across subjects.
    func adaptivity(for subjectID: String, language: String) -> Adaptivity {
        let progress = subjectProgress(for: subjectID, language: language)
        return Adaptivity(adjustment: progress?.adjustment ?? difficultyAdjustment, perfectRounds: progress?.perfectRounds ?? 0)
    }

    func difficulty(for subjectID: String, language: String) -> Difficulty {
        DifficultyScale.difficulty(forAge: age, adjustment: adaptivity(for: subjectID, language: language).adjustment)
    }

    /// The age a subject's questions are made for, e.g. 8.5 for a 7-year-old who is 1½ years ahead.
    func levelAge(for subjectID: String, language: String) -> Double {
        DifficultyScale.effectiveAge(age: age, adjustment: adaptivity(for: subjectID, language: language).adjustment)
    }

    /// Changing the age resets adaptivity so the new age is the fresh baseline.
    func setAge(_ newAge: Int) {
        let clamped = newAge.clamped(to: DifficultyTuning.ageRange)
        guard clamped != age else { return }
        age = clamped
        difficultyAdjustment = 0
        for subject in progress {
            subject.adjustment = 0
            subject.perfectRounds = 0
        }
        if !DifficultyScale.difficulty(forAge: clamped).allowsGentleTimer {
            gentleTimerEnabled = false
        }
    }

    func isSubjectEnabled(_ subjectID: String) -> Bool {
        enabledSubjectIDs.isEmpty || enabledSubjectIDs.contains(subjectID)
    }

    func subjectProgress(for subjectID: String, language: String) -> SubjectProgress? {
        progress.first { $0.subjectID == subjectID && $0.languageCode == language }
    }
}
