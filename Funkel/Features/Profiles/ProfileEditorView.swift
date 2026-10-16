import SwiftData
import SwiftUI

/// Create or edit a profile: name, age, colour. The full grown-up settings
/// (language, subjects, toggles) arrive with the grown-up area (milestone 6).
struct ProfileEditorView: View {
    let profile: ChildProfile?
    var onSave: (ChildProfile) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var age = 6
    @State private var avatarColor = "sun"

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Pip(color: Palette.avatarColor(avatarColor), mood: .happy)
                            .frame(width: 110, height: 110)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("editor.name") {
                    TextField("editor.name.placeholder", text: $name)
                        .font(.funkelHeadline)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                }

                Section("editor.age") {
                    Stepper(value: $age, in: DifficultyTuning.ageRange) {
                        Text("profile.age \(age)")
                            .font(.funkelHeadline)
                    }
                }

                Section("editor.color") {
                    colorPicker
                }

                Section {
                    Label("editor.privacy", systemImage: "lock.fill")
                        .font(.funkelCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(profile == nil ? LocalizedStringKey("editor.title.new") : LocalizedStringKey("editor.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("editor.save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(Palette.avatarColors, id: \.key) { entry in
                Button {
                    avatarColor = entry.key
                } label: {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if avatarColor == entry.key {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("color." + entry.key)))
                .accessibilityAddTraits(avatarColor == entry.key ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func load() {
        guard let profile else { return }
        name = profile.name
        age = profile.age
        avatarColor = profile.avatarColor
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let saved: ChildProfile
        if let profile {
            profile.name = trimmedName
            profile.setAge(age)
            profile.avatarColor = avatarColor
            saved = profile
        } else {
            saved = ChildProfile(name: trimmedName, age: age, avatarColor: avatarColor)
            modelContext.insert(saved)
        }
        try? modelContext.save()
        onSave(saved)
        dismiss()
    }
}
