import SwiftData
import SwiftUI

/// Chooses between the profile picker and the active child's home screen.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \ChildProfile.createdAt) private var profiles: [ChildProfile]
    @AppStorage(AppLaunch.activeProfileKey) private var activeProfileID = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var activeProfile: ChildProfile? {
        profiles.first { $0.id.uuidString == activeProfileID }
    }

    var body: some View {
        Group {
            if let profile = activeProfile,
               let language = environment.content.resolvedLanguage(code: profile.learningLanguage) {
                NavigationStack {
                    HomeView(profile: profile, language: language) {
                        activeProfileID = ""
                    }
                }
                .id(profile.id)
            } else if environment.content.languages.isEmpty {
                ContentUnavailableView("content.missing", systemImage: "exclamationmark.triangle")
            } else {
                ProfilePickerView(profiles: profiles) { profile in
                    activeProfileID = profile.id.uuidString
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: activeProfileID)
        .task { refreshAges() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshAges() }
        }
    }

    /// Birthdays since the last visit: ages go up by themselves.
    private func refreshAges() {
        let changed = profiles.map { $0.refreshAgeFromBirthday() }
        if changed.contains(true) { try? modelContext.save() }
    }
}
