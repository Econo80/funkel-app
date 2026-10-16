import SwiftData
import SwiftUI

/// The grown-up area: manage children's profiles, plus the privacy statement.
struct GrownUpsView: View {
    @Query(sort: \ChildProfile.createdAt) private var profiles: [ChildProfile]
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingProfile = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("grownups.profiles") {
                    ForEach(profiles) { profile in
                        NavigationLink {
                            ProfileEditorView(profile: profile)
                        } label: {
                            ProfileRow(profile: profile)
                        }
                        .accessibilityIdentifier("settings-profile-\(profile.name)")
                    }
                    Button {
                        isAddingProfile = true
                    } label: {
                        Label("profiles.add", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("settings-add-profile")
                }

                Section("grownups.privacy.title") {
                    Text("grownups.privacy.text")
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)
                    LabeledContent("grownups.version", value: version)
                }
            }
            .navigationTitle("grownups.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("grownups.done") { dismiss() }
                        .accessibilityIdentifier("grownups-done")
                }
            }
            .sheet(isPresented: $isAddingProfile) {
                NavigationStack {
                    ProfileEditorView(profile: nil)
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: ChildProfile

    var body: some View {
        HStack(spacing: 14) {
            Pip(color: Palette.avatarColor(profile.avatarColor))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.funkelHeadline)
                Text("profile.age \(profile.age)")
                    .font(.funkelCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
