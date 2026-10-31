import SwiftData
import XCTest
@testable import Funkel

/// TEMPORARY: logs what the old restore (delete + insert in one save) keeps. Remove before merging.
@MainActor
final class RestoreDiagnosisTests: XCTestCase {
    func testDiagnoseOldRestore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diag-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let container = try ModelContainer(for: ChildProfile.self, SubjectProgress.self, RoundRecord.self, configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        func json(_ stars: Int) -> [String: Any] {
            ["id": "3f2b6a1c-8d4e-4f5a-9b7c-1e2d3c4b5a69", "name": "Lena", "age": 5, "totalStars": stars, "farmXp": stars,
             "progress": ["de/maths": ["roundsPlayed": stars]]]
        }
        func oldRestore(_ stars: Int) throws {
            for p in try context.fetch(FetchDescriptor<ChildProfile>()) { context.delete(p) }
            _ = Backup.makeProfile(from: json(stars), in: context)
            try context.save()
        }
        try oldRestore(10)
        var saveError = "none"
        do { try oldRestore(62) } catch { saveError = "\(error)" }
        let fresh = ModelContext(container)
        let profiles = try fresh.fetch(FetchDescriptor<ChildProfile>())
        let line = "DIAG old restore: saveError=\(saveError) profiles=\(profiles.count) stars=\(profiles.map(\.totalStars)) farmXp=\(profiles.map { $0.webField("farmXp", as: Int.self) ?? -1 }) progress=\(try fresh.fetchCount(FetchDescriptor<SubjectProgress>()))"
        print(line)
        XCTContext.runActivity(named: line) { _ in }
    }
}
