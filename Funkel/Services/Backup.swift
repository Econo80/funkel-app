import Foundation
import SwiftData

/// Backups in the web app's format (web/src/domain/backup.ts), so families can
/// move between the web app and this app in both directions. A backup is one
/// JSON file a grown-up keeps (Files, iCloud Drive …); nothing is uploaded.
///
/// ```json
/// { "app": "funkel", "version": 1, "exportedAt": "2026-10-18T09:00:00.000Z",
///   "profiles": [ { "id": "…", "name": "Lena", "age": 5, "totalStars": 62, … } ] }
/// ```
enum Backup {
    static let app = "funkel"
    static let version = 1

    enum Problem: String, Error, Equatable {
        case notJson, notFunkel, newerVersion, noProfiles
    }

    /// One profile from a backup file: what the confirmation shows, plus the raw object.
    struct ProfileEntry: Identifiable {
        let json: [String: Any]
        var id: String { json["id"] as? String ?? "" }
        var name: String { json["name"] as? String ?? "" }
        var age: Int { Backup.int(json["age"]) ?? DifficultyTuning.minAge }
        var totalStars: Int { Backup.int(json["totalStars"]) ?? 0 }
        var walletStars: Int { Backup.int(json["walletStars"]) ?? totalStars }
    }

    struct Contents: Identifiable {
        let id = UUID()
        let exportedAt: Date?
        let profiles: [ProfileEntry]
    }

    static func fileName(at now: Date = .now, calendar: Calendar = .current) -> String {
        "Funkel-Sicherung-\(dayKey(now, calendar: calendar)).json"
    }

    // MARK: Writing

    static func export(_ profiles: [ChildProfile], at now: Date = .now, calendar: Calendar = .current) throws -> Data {
        let root: [String: Any] = [
            "app": app,
            "version": version,
            "exportedAt": isoString(now),
            "profiles": profiles.map { webProfile($0, calendar: calendar) },
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// A profile as the web app stores it. Starts from what the web app kept
    /// (garden, games …) and overwrites everything this app knows.
    static func webProfile(_ profile: ChildProfile, calendar: Calendar = .current) -> [String: Any] {
        var p = BackupExtras.decode(profile.backupExtras)
        if p["id"] as? String == nil { p["id"] = profile.id.uuidString.lowercased() }
        p["name"] = profile.name
        p["age"] = profile.age
        p["avatarColor"] = profile.avatarColor
        p["learningLanguage"] = profile.learningLanguage
        p["enabledSubjectIds"] = profile.enabledSubjectIDs.sorted()
        p["roundLength"] = profile.roundLength
        p["soundEnabled"] = profile.soundEnabled
        p["readAloudEnabled"] = profile.readAloudEnabled
        p["hapticsEnabled"] = profile.hapticsEnabled
        p["gentleTimerEnabled"] = profile.gentleTimerEnabled
        p["createdAt"] = isoString(profile.createdAt)
        p["difficultyAdjustment"] = profile.difficultyAdjustment
        p["totalStars"] = profile.totalStars
        p["walletStars"] = profile.walletStars
        p["giftStars"] = profile.giftStars
        p["currentStreak"] = profile.currentStreak
        p["longestStreak"] = profile.longestStreak
        p["lastPlayedDay"] = profile.lastPlayedDay.map { dayKey($0, calendar: calendar) }

        var progress: [String: Any] = [:]
        for subject in profile.progress {
            var entry: [String: Any] = [
                "roundsPlayed": subject.roundsPlayed,
                "questionsAnswered": subject.questionsAnswered,
                "correctAnswers": subject.correctAnswers,
                "stars": subject.stars,
                "recentCorrectContentIds": subject.recentCorrectContentIDs,
                "perfectRounds": subject.perfectRounds,
            ]
            entry["lastPlayed"] = subject.lastPlayed.map { isoString($0) }
            entry["adjustment"] = subject.adjustment
            progress["\(subject.languageCode)/\(subject.subjectID)"] = entry
        }
        p["progress"] = progress

        p["rounds"] = profile.rounds.sorted { $0.date < $1.date }.map { round -> [String: Any] in
            [
                "date": isoString(round.date),
                "subjectId": round.subjectID,
                "languageCode": round.languageCode,
                "correct": round.correct,
                "total": round.total,
                "starsEarned": round.starsEarned,
                "effectiveAge": round.effectiveAge,
            ]
        }
        return p
    }

    // MARK: Reading

    static func read(_ data: Data) -> Result<Contents, Problem> {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return .failure(.notJson) }
        guard let root = object as? [String: Any], root["app"] as? String == app, let list = root["profiles"] as? [Any] else {
            return .failure(.notFunkel)
        }
        guard let fileVersion = int(root["version"]), fileVersion <= version else { return .failure(.newerVersion) }
        let profiles = list
            .compactMap { $0 as? [String: Any] }
            .filter { $0["id"] is String && $0["name"] is String }
            .map(ProfileEntry.init(json:))
        guard !profiles.isEmpty else { return .failure(.noProfiles) }
        return .success(Contents(exportedAt: (root["exportedAt"] as? String).flatMap { Backup.date(fromISO: $0) }, profiles: profiles))
    }

    /// Replaces every profile on this device by the ones in the backup.
    @discardableResult
    static func restore(_ contents: Contents, into context: ModelContext, calendar: Calendar = .current) throws -> [ChildProfile] {
        for profile in try context.fetch(FetchDescriptor<ChildProfile>()) {
            context.delete(profile)
        }
        // Save the deletions first: a backup of these same profiles carries
        // their ids, and inserting a profile whose unique id is still waiting
        // to be deleted makes SwiftData merge it into the old one, keeping the old data.
        try context.save()
        var seen = Set<String>()
        let entries = contents.profiles.filter { seen.insert($0.id.lowercased()).inserted }
        let profiles = entries.map { makeProfile(from: $0.json, in: context, calendar: calendar) }
        try context.save()
        return profiles
    }

    /// Builds a profile from a web profile object. Missing fields get the same
    /// defaults the web app uses for old profiles.
    static func makeProfile(from json: [String: Any], in context: ModelContext, calendar: Calendar = .current) -> ChildProfile {
        let profile = ChildProfile(
            name: json["name"] as? String ?? "",
            age: int(json["age"]) ?? 6,
            avatarColor: json["avatarColor"] as? String ?? "sun",
            learningLanguage: json["learningLanguage"] as? String ?? ContentLibrary.fallbackLanguageCode,
            roundLength: int(json["roundLength"]) ?? ProfileDefaults.roundLength
        )
        if let id = (json["id"] as? String).flatMap(UUID.init(uuidString:)) { profile.id = id }
        profile.enabledSubjectIDs = (json["enabledSubjectIds"] as? [String] ?? []).sorted()
        profile.soundEnabled = json["soundEnabled"] as? Bool ?? true
        profile.readAloudEnabled = json["readAloudEnabled"] as? Bool ?? true
        profile.hapticsEnabled = json["hapticsEnabled"] as? Bool ?? true
        profile.gentleTimerEnabled = json["gentleTimerEnabled"] as? Bool ?? false
        profile.createdAt = (json["createdAt"] as? String).flatMap { Backup.date(fromISO: $0) } ?? .now
        profile.difficultyAdjustment = double(json["difficultyAdjustment"]) ?? 0
        profile.totalStars = int(json["totalStars"]) ?? 0
        profile.walletStars = int(json["walletStars"]) ?? profile.totalStars
        profile.giftStars = int(json["giftStars"]) ?? 0
        profile.walletReady = true
        profile.currentStreak = int(json["currentStreak"]) ?? 0
        profile.longestStreak = int(json["longestStreak"]) ?? 0
        profile.lastPlayedDay = (json["lastPlayedDay"] as? String).flatMap { date(fromDayKey: $0, calendar: calendar) }
        profile.backupExtras = BackupExtras.encode(BackupExtras.unknownFields(of: json))
        context.insert(profile)

        for (key, value) in json["progress"] as? [String: Any] ?? [:] {
            guard let entry = value as? [String: Any], let slash = key.firstIndex(of: "/") else { continue }
            let progress = SubjectProgress(subjectID: String(key[key.index(after: slash)...]), languageCode: String(key[..<slash]))
            progress.roundsPlayed = int(entry["roundsPlayed"]) ?? 0
            progress.questionsAnswered = int(entry["questionsAnswered"]) ?? 0
            progress.correctAnswers = int(entry["correctAnswers"]) ?? 0
            progress.stars = int(entry["stars"]) ?? 0
            progress.lastPlayed = (entry["lastPlayed"] as? String).flatMap { Backup.date(fromISO: $0) }
            progress.recentCorrectContentIDs = entry["recentCorrectContentIds"] as? [String] ?? []
            progress.adjustment = double(entry["adjustment"])
            progress.perfectRounds = int(entry["perfectRounds"]) ?? 0
            context.insert(progress)
            profile.progress.append(progress)
        }

        for case let entry as [String: Any] in json["rounds"] as? [Any] ?? [] {
            let round = RoundRecord(
                date: (entry["date"] as? String).flatMap { Backup.date(fromISO: $0) } ?? profile.createdAt,
                subjectID: entry["subjectId"] as? String ?? "",
                languageCode: entry["languageCode"] as? String ?? profile.learningLanguage,
                correct: int(entry["correct"]) ?? 0,
                total: int(entry["total"]) ?? 0,
                starsEarned: int(entry["starsEarned"]) ?? 0,
                effectiveAge: double(entry["effectiveAge"]) ?? Double(profile.age)
            )
            context.insert(round)
            profile.rounds.append(round)
        }
        return profile
    }

    // MARK: Values

    static func int(_ value: Any?) -> Int? {
        (value as? NSNumber).map { Int(truncating: $0) }
    }

    static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    /// Like JavaScript's `toISOString()`: UTC with milliseconds.
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func date(fromISO text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    /// Local calendar day, "YYYY-MM-DD", like the web app's `dayKey`.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// The parts of a web profile this app doesn't use yet, kept as JSON.
enum BackupExtras {
    /// Fields this app stores in its own models (everything else is kept as is, `id` included).
    static let knownFields: Set<String> = [
        "name", "age", "avatarColor", "learningLanguage", "enabledSubjectIds", "roundLength",
        "soundEnabled", "readAloudEnabled", "hapticsEnabled", "gentleTimerEnabled", "createdAt",
        "difficultyAdjustment", "totalStars", "walletStars", "giftStars", "currentStreak",
        "longestStreak", "lastPlayedDay", "progress", "rounds",
    ]

    /// Game and garden progress, cleared by "Fortschritt zurücksetzen" like in the web app.
    static let progressFields: Set<String> = [
        "garden", "farmGoods", "farmXp", "farmOrders", "gamesToday", "gameDay",
        "bonusGames", "bonusDay", "gardenDay", "gardenSeconds", "gardenBonusMinutes",
    ]

    static func unknownFields(of json: [String: Any]) -> [String: Any] {
        json.filter { !knownFields.contains($0.key) }
    }

    static func withoutProgress(_ data: Data?) -> Data? {
        guard data != nil else { return nil }
        return encode(decode(data).filter { !progressFields.contains($0.key) })
    }

    static func decode(_ data: Data?) -> [String: Any] {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    static func encode(_ fields: [String: Any]) -> Data? {
        fields.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }
}
