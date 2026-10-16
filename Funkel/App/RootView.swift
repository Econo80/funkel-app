import SwiftData
import SwiftUI

/// Chooses between the profile picker and the active child's home screen.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \ChildProfile.createdAt) private var profiles: [ChildProfile]
    @AppStorage("activeProfileID") private var activeProfileID = ""

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
    }
}
