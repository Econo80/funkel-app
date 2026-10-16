import Foundation
import SwiftData

/// Builds the SwiftData store. UI tests (Debug only) get a fresh in-memory
/// store seeded with sample profiles, so screenshots are reproducible.
enum AppLaunch {
    static let activeProfileKey = "activeProfileID"

    static var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
        return false
        #endif
    }

    /// `-forceVocabularyType spelling` makes every vocabulary question that type (Debug only).
    static var forcedVocabularyType: VocabularyQuestionType? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-forceVocabularyType"), args.indices.contains(flag + 1) else { return nil }
        return VocabularyQuestionType(rawValue: args[flag + 1])
        #else
        return nil
        #endif
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([ChildProfile.self, SubjectProgress.self, RoundRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            #if DEBUG
            if isUITesting {
                UserDefaults.standard.removeObject(forKey: activeProfileKey)
                UITestFixtures.seed(container.mainContext)
            }
            #endif
            return container
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }
}

#if DEBUG
/// Sample children for UI tests and screenshots.
enum UITestFixtures {
    @MainActor
    static func seed(_ context: ModelContext) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)

        let lena = ChildProfile(name: "Lena", age: 5, avatarColor: "berry", roundLength: 5)
        lena.totalStars = 42
        lena.currentStreak = 3
        lena.longestStreak = 5
        lena.lastPlayedDay = yesterday
        lena.readAloudEnabled = false
        context.insert(lena)

        let maths = SubjectProgress(subjectID: "maths", languageCode: "de")
        maths.roundsPlayed = 6
        maths.questionsAnswered = 30
        maths.correctAnswers = 24
        maths.stars = 24
        context.insert(maths)
        lena.progress.append(maths)

        let emil = ChildProfile(name: "Emil", age: 10, avatarColor: "sky", roundLength: 5)
        emil.createdAt = lena.createdAt.addingTimeInterval(1)
        emil.totalStars = 318
        emil.currentStreak = 12
        emil.longestStreak = 12
        emil.lastPlayedDay = yesterday
        context.insert(emil)

        try? context.save()
    }
}
#endif
