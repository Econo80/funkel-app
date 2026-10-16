import SwiftUI

/// "Wer lernt heute?" — big avatar tiles, one per child.
struct ProfilePickerView: View {
    let profiles: [ChildProfile]
    let onSelect: (ChildProfile) -> Void

    @State private var isAddingProfile = false

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Pip(color: Palette.sun, mood: profiles.isEmpty ? .happy : .cheering)
                    .frame(width: 120, height: 120)
                    .padding(.top, 32)

                if profiles.isEmpty {
                    emptyState
                } else {
                    Text("profiles.title")
                        .font(.funkelTitle)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(profiles) { profile in
                            ProfileTile(profile: profile) { onSelect(profile) }
                        }
                        addTile
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $isAddingProfile) {
            ProfileEditorView(profile: nil) { created in
                onSelect(created)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("profiles.empty.title")
                .font(.funkelTitle)
                .foregroundStyle(Palette.ink)
            Text("profiles.empty.message")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            BigButton(title: "profiles.add", systemImage: "plus") {
                isAddingProfile = true
            }
            .frame(maxWidth: 360)
            .padding(.top, 8)
        }
    }

    private var addTile: some View {
        Button {
            isAddingProfile = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 96, height: 96)
                    .background(Color.secondary.opacity(0.12), in: .circle)
                Text("profiles.add")
                    .font(.funkelCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 190)
            .funkelCard()
        }
        .buttonStyle(PressableStyle())
    }
}

private struct ProfileTile: View {
    let profile: ChildProfile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Pip(color: Palette.avatarColor(profile.avatarColor))
                    .frame(width: 96, height: 96)
                Text(profile.name)
                    .font(.funkelHeadline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("profile.age \(profile.age)")
                    .font(.funkelCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 190)
            .funkelCard()
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("profile-\(profile.name)")
    }
}
