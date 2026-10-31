import Foundation

/// An editable copy of a profile's settings. The editor works on this value
/// and only writes it back on save, so "back" discards changes.
struct ProfileSettings: Equatable {
    static let roundLengthChoices = [5, 10, 15, 20]

    var name = ""
    var age = 6
    var avatarColor = "sun"
    var learningLanguage = ContentLibrary.fallbackLanguageCode
    /// Empty means "all subjects the learning language offers" — so subjects a
    /// language gains later (e.g. Grammar) are on by default.
    var enabledSubjectIDs: Set<String> = []
    var roundLength = ProfileDefaults.roundLength
    var soundEnabled = true
    var readAloudEnabled = true
    var hapticsEnabled = true
    var gentleTimerEnabled = false
    // Spielecke (stored as web fields, see ChildProfile+Play.swift)
    var gamesEnabled = true
    var gameCost = 10
    var gamesPerDay = 3
    var gameDifficulty = GameDifficulty.normal

    init() {}

    init(profile: ChildProfile) {
        name = profile.name
        age = profile.age
        avatarColor = profile.avatarColor
        learningLanguage = profile.learningLanguage
        enabledSubjectIDs = Set(profile.enabledSubjectIDs)
        roundLength = profile.roundLength
        soundEnabled = profile.soundEnabled
        readAloudEnabled = profile.readAloudEnabled
        hapticsEnabled = profile.hapticsEnabled
        gentleTimerEnabled = profile.gentleTimerEnabled
        let play = profile.playState
        gamesEnabled = play.gamesEnabled
        gameCost = play.gameCost
        gamesPerDay = play.gamesPerDay
        gameDifficulty = play.gameDifficulty
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty }

    /// The soft timer is only offered from age 9 (PLAN.md §5.1).
    var allowsGentleTimer: Bool {
        DifficultyScale.difficulty(forAge: age).allowsGentleTimer
    }

    // MARK: Subjects

    func isSubjectEnabled(_ id: String) -> Bool {
        enabledSubjectIDs.isEmpty || enabledSubjectIDs.contains(id)
    }

    /// Toggles a subject. At least one subject always stays on; turning
    /// everything back on stores "all" (empty).
    mutating func setSubject(_ id: String, enabled: Bool, available: [String]) {
        var current = enabledSubjectIDs.isEmpty ? Set(available) : enabledSubjectIDs
        if enabled {
            current.insert(id)
        } else {
            guard current.subtracting([id]).isEmpty == false else { return }
            current.remove(id)
        }
        enabledSubjectIDs = current.isSuperset(of: available) ? [] : current
    }

    func isLastEnabledSubject(_ id: String, available: [String]) -> Bool {
        let current = enabledSubjectIDs.isEmpty ? Set(available) : enabledSubjectIDs
        return current == [id]
    }

    /// Subjects differ per language, so switching language turns all of them on.
    mutating func setLearningLanguage(_ code: String) {
        guard code != learningLanguage else { return }
        learningLanguage = code
        enabledSubjectIDs = []
    }

    // MARK: Writing back

    func apply(to profile: ChildProfile) {
        profile.name = trimmedName
        profile.setAge(age)   // resets adaptivity when the age changes
        profile.avatarColor = avatarColor
        profile.learningLanguage = learningLanguage
        profile.enabledSubjectIDs = enabledSubjectIDs.sorted()
        profile.roundLength = roundLength.clamped(to: ProfileDefaults.roundLengthRange)
        profile.soundEnabled = soundEnabled
        profile.readAloudEnabled = readAloudEnabled
        profile.hapticsEnabled = hapticsEnabled
        profile.gentleTimerEnabled = gentleTimerEnabled && allowsGentleTimer
        profile.setGameSettings(enabled: gamesEnabled, cost: gameCost, perDay: gamesPerDay, difficulty: gameDifficulty)
    }

    func makeProfile() -> ChildProfile {
        let profile = ChildProfile(name: trimmedName, age: age, avatarColor: avatarColor, learningLanguage: learningLanguage)
        apply(to: profile)
        return profile
    }
}
