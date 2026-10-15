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
    /// Performance-driven offset on top of `age` (PLAN.md §5.4).
    var difficultyAdjustment: Double
    /// Empty means "all subjects the learning language offers".
    var enabledSubjectIDs: [String]
    var roundLength: Int
    var soundEnabled: Bool
    var readAloudEnabled: Bool
    var hapticsEnabled: Bool
    var gentleTimerEnabled: Bool
    var totalStars: Int
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
    var difficulty: Difficulty {
        DifficultyScale.difficulty(forAge: age, adjustment: difficultyAdjustment)
    }

    /// Changing the age resets adaptivity so the new age is the fresh baseline.
    func setAge(_ newAge: Int) {
        let clamped = newAge.clamped(to: DifficultyTuning.ageRange)
        guard clamped != age else { return }
        age = clamped
        difficultyAdjustment = 0
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
