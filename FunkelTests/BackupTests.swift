import SwiftData
import XCTest
@testable import Funkel

/// Mirrors web/tests/backup.test.ts: the same file format in both apps.
@MainActor
final class BackupTests: XCTestCase {

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

    /// Shaped like a file saved by the web app (web/src/domain/backup.ts), including
    /// things only the web app has so far: the farm, games and Sudoku.
    private let webBackup = """
    {
      "app": "funkel",
      "version": 1,
      "exportedAt": "2026-10-18T09:00:00.000Z",
      "profiles": [
        {
          "id": "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69",
          "name": "Lena", "age": 5, "avatarColor": "berry", "learningLanguage": "de",
          "enabledSubjectIds": [], "roundLength": 10,
          "soundEnabled": true, "readAloudEnabled": true, "hapticsEnabled": false, "gentleTimerEnabled": false,
          "gamesEnabled": true, "gameCost": 5, "gamesPerDay": 3, "gameDifficulty": "hard",
          "gardenMinutesPerDay": 20, "sudokuEnabled": true, "sudokuDifficulty": "normal",
          "createdAt": "2026-10-16T12:59:00.000Z", "difficultyAdjustment": 0.45,
          "totalStars": 62, "walletStars": 123, "giftStars": 60,
          "gamesToday": 1, "gameDay": "2026-10-18", "bonusGames": 0,
          "garden": [{ "itemId": "barn", "plantedDay": "2026-10-14" }, null, { "itemId": "cow", "plantedDay": "2026-10-16" }],
          "gardenColumns": 16, "farmGoods": { "egg": 3, "milk": 1, "wheat": 0, "veg": 0, "apple": 0, "honey": 0 }, "farmXp": 140,
          "currentStreak": 2, "longestStreak": 4, "lastPlayedDay": "2026-10-18",
          "progress": {
            "de/maths": { "roundsPlayed": 5, "questionsAnswered": 50, "correctAnswers": 47, "stars": 47,
                          "lastPlayed": "2026-10-18T08:30:00.000Z", "recentCorrectContentIds": ["a", "b"],
                          "adjustment": 1.45, "perfectRounds": 3 },
            "puzzle/sudoku": { "roundsPlayed": 1, "questionsAnswered": 0, "correctAnswers": 0, "stars": 3, "recentCorrectContentIds": [] }
          },
          "rounds": [
            { "date": "2026-10-18T08:30:00.000Z", "subjectId": "maths", "languageCode": "de",
              "correct": 10, "total": 10, "starsEarned": 10, "effectiveAge": 5.95 }
          ]
        },
        { "id": "p-1729000000-x1", "name": "Emil", "age": 10, "totalStars": 8 }
      ]
    }
    """

    private func contents(_ text: String) throws -> Backup.Contents {
        switch Backup.read(Data(text.utf8)) {
        case .success(let contents): return contents
        case .failure(let problem): throw problem
        }
    }

    func testReadsAWebBackupIntoTheApp() throws {
        let context = try makeContext()
        let contents = try contents(webBackup)
        XCTAssertEqual(contents.profiles.map(\.name), ["Lena", "Emil"])
        XCTAssertEqual(contents.profiles[0].walletStars, 123)
        XCTAssertEqual(contents.exportedAt, Backup.date(fromISO: "2026-10-18T09:00:00.000Z"))

        let restored = try Backup.restore(contents, into: context, calendar: calendar)
        let lena = restored[0]
        XCTAssertEqual(lena.id, UUID(uuidString: "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69"))
        XCTAssertEqual(lena.age, 5)
        XCTAssertEqual(lena.avatarColor, "berry")
        XCTAssertFalse(lena.hapticsEnabled)
        XCTAssertEqual(lena.totalStars, 62)
        XCTAssertEqual(lena.walletStars, 123)
        XCTAssertEqual(lena.giftStars, 60)
        XCTAssertEqual(lena.currentStreak, 2)
        XCTAssertEqual(lena.lastPlayedDay, calendar.date(from: DateComponents(year: 2026, month: 10, day: 18)))
        XCTAssertEqual(lena.adaptivity(for: "maths", language: "de"), Adaptivity(adjustment: 1.45, perfectRounds: 3))
        XCTAssertEqual(lena.subjectProgress(for: "maths", language: "de")?.recentCorrectContentIDs, ["a", "b"])
        XCTAssertEqual(lena.subjectProgress(for: "sudoku", language: "puzzle")?.stars, 3)
        XCTAssertEqual(lena.rounds.count, 1)
        XCTAssertEqual(lena.rounds.first?.effectiveAge, 5.95)

        // Fields of an old profile get the web app's defaults; a non-UUID id gets a new one.
        let emil = restored[1]
        XCTAssertEqual(emil.walletStars, 8, "stars earned before the wallet existed can be spent")
        XCTAssertTrue(emil.readAloudEnabled)
        XCTAssertTrue(emil.walletReady)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChildProfile>()), 2)
    }

    func testRestoringReplacesTheProfilesOnTheDevice() throws {
        let context = try makeContext()
        let old = ChildProfile(name: "Alt", age: 7)
        context.insert(old)
        ProgressRecorder(context: context).record(
            RoundOutcome(subjectID: "maths", languageCode: "de", correct: 5, total: 10, correctContentIDs: [], effectiveAge: 7), for: old
        )
        try Backup.restore(try contents(webBackup), into: context, calendar: calendar)
        let names = try context.fetch(FetchDescriptor<ChildProfile>()).map(\.name).sorted()
        XCTAssertEqual(names, ["Emil", "Lena"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RoundRecord>()), 1, "the old profile's history went with it")
    }

    /// The usual case on a device: the profiles came from an earlier backup,
    /// so the new file has the same profile ids. Its data must win.
    func testRestoringANewerBackupOfTheSameProfilesTakesItsData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let container = try ModelContainer(
            for: ChildProfile.self, SubjectProgress.self, RoundRecord.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)

        let older = webBackup
            .replacingOccurrences(of: "\"totalStars\": 62", with: "\"totalStars\": 10")
            .replacingOccurrences(of: "\"farmXp\": 140", with: "\"farmXp\": 5")
        try Backup.restore(try contents(older), into: context, calendar: calendar)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChildProfile>()).first { $0.name == "Lena" }?.totalStars, 10)

        try Backup.restore(try contents(webBackup), into: context, calendar: calendar)

        // Read back through a fresh context, like the app after the restore.
        let fresh = ModelContext(container)
        let profiles = try fresh.fetch(FetchDescriptor<ChildProfile>())
        XCTAssertEqual(profiles.map(\.name).sorted(), ["Emil", "Lena"])
        let lena = try XCTUnwrap(profiles.first { $0.name == "Lena" })
        XCTAssertEqual(lena.id.uuidString.lowercased(), "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69")
        XCTAssertEqual(lena.totalStars, 62)
        XCTAssertEqual(lena.walletStars, 123)
        XCTAssertEqual(lena.currentStreak, 2)
        XCTAssertEqual(lena.webField("farmXp", as: Int.self), 140)
        XCTAssertEqual(lena.webField("garden", as: [GardenSlotProbe?].self)?.count, 3)
        XCTAssertEqual(lena.subjectProgress(for: "maths", language: "de")?.roundsPlayed, 5)
        XCTAssertEqual(lena.sudokusSolved, 1)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<SubjectProgress>()), 2)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<RoundRecord>()), 1)
    }

    func testAWebBackupComesBackOutWithNothingLost() throws {
        let context = try makeContext()
        let lena = try Backup.restore(try contents(webBackup), into: context, calendar: calendar)[0]
        ProgressRecorder(context: context).record(
            RoundOutcome(subjectID: "vocabulary", languageCode: "de", correct: 4, total: 5, correctContentIDs: ["w"], effectiveAge: 5), for: lena
        )

        let data = try Backup.export([lena], at: Backup.date(fromISO: "2026-10-30T10:00:00.000Z")!, calendar: calendar)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["app"] as? String, "funkel")
        XCTAssertEqual(root["version"] as? Int, 1)
        XCTAssertEqual(root["exportedAt"] as? String, "2026-10-30T10:00:00.000Z")
        let p = try XCTUnwrap((root["profiles"] as? [[String: Any]])?.first)

        // What only the web app knows stays untouched …
        XCTAssertEqual(p["id"] as? String, "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69")
        XCTAssertEqual((p["garden"] as? [Any])?.count, 3)
        XCTAssertEqual(p["farmXp"] as? Int, 140)
        XCTAssertEqual(p["gameDifficulty"] as? String, "hard")
        XCTAssertEqual((p["farmGoods"] as? [String: Any])?["egg"] as? Int, 3)
        // … and what this app changed is in the web app's shape.
        XCTAssertEqual(p["totalStars"] as? Int, 66)
        XCTAssertEqual(p["walletStars"] as? Int, 127)
        XCTAssertEqual(p["lastPlayedDay"] as? String, Backup.dayKey(try XCTUnwrap(lena.lastPlayedDay), calendar: calendar))
        let progress = try XCTUnwrap(p["progress"] as? [String: [String: Any]])
        XCTAssertEqual(Set(progress.keys), ["de/maths", "de/vocabulary", "puzzle/sudoku"])
        XCTAssertEqual(progress["de/maths"]?["adjustment"] as? Double, 1.45)
        XCTAssertEqual(progress["de/vocabulary"]?["recentCorrectContentIds"] as? [String], ["w"])
        XCTAssertEqual((p["rounds"] as? [Any])?.count, 2)
    }

    func testANativeProfileRoundTrips() throws {
        let context = try makeContext()
        let profile = ChildProfile(name: "Ida", age: 9)
        context.insert(profile)
        ProfileMaintenance.giveStars(25, to: profile)
        ProfileMaintenance.setSubjectAdjustment(1, subjectID: "maths", language: "de", of: profile, in: context)

        let data = try Backup.export([profile], calendar: calendar)
        let restored = try Backup.restore(try contents(String(decoding: data, as: UTF8.self)), into: try makeContext(), calendar: calendar)
        XCTAssertEqual(restored.first?.id, profile.id)
        XCTAssertEqual(restored.first?.walletStars, 25)
        XCTAssertEqual(restored.first?.adaptivity(for: "maths", language: "de").adjustment, 1)
        XCTAssertEqual(Backup.fileName(at: Backup.date(fromISO: "2026-10-18T10:00:00.000Z")!, calendar: calendar), "Funkel-Sicherung-2026-10-18.json")
    }

    func testExplainsFilesThatArentUsable() {
        func problem(_ text: String) -> Backup.Problem? {
            if case .failure(let problem) = Backup.read(Data(text.utf8)) { return problem }
            return nil
        }
        XCTAssertEqual(problem("not json"), .notJson)
        XCTAssertEqual(problem(#"{"hello": 1}"#), .notFunkel)
        XCTAssertEqual(problem(#"{"app": "funkel", "version": 99, "profiles": []}"#), .newerVersion)
        XCTAssertEqual(problem(#"{"app": "funkel", "version": 1, "profiles": [{"nope": true}]}"#), .noProfiles)
    }
}

/// Just enough of a garden slot to count them.
private struct GardenSlotProbe: Decodable {
    let itemId: String
}
