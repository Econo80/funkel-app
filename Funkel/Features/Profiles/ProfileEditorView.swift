import SwiftData
import SwiftUI

/// Create or edit a child's profile and all of its settings.
/// Shown inside a NavigationStack (pushed or in a sheet). Grown-ups only:
/// always reached through the gate.
struct ProfileEditorView: View {
    let profile: ChildProfile?
    var onSave: (ChildProfile) -> Void = { _ in }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var settings = ProfileSettings()
    @State private var hasLoaded = false
    @State private var confirmsReset = false
    @State private var confirmsDelete = false

    private var language: ContentLanguage? {
        environment.content.resolvedLanguage(code: settings.learningLanguage)
    }

    private var subjectIDs: [String] {
        language?.subjects.map(\.id) ?? []
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Pip(color: Palette.avatarColor(settings.avatarColor), mood: .happy)
                        .frame(width: 96, height: 96)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("editor.name") {
                TextField("editor.name.placeholder", text: $settings.name)
                    .font(.funkelHeadline)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .accessibilityIdentifier("editor-name")
            }

            Section("editor.age") {
                Stepper(value: $settings.age, in: DifficultyTuning.ageRange) {
                    Text("profile.age \(settings.age)")
                        .font(.funkelHeadline)
                }
            }

            Section("editor.color") {
                colorPicker
            }

            Section {
                Picker("editor.language", selection: languageBinding) {
                    ForEach(environment.content.languages) { language in
                        Text(verbatim: language.name).tag(language.code)
                    }
                }
            } footer: {
                Text("editor.language.footer")
            }

            Section {
                ForEach(language?.subjects ?? []) { subject in
                    Toggle(isOn: subjectBinding(subject.id)) {
                        Label {
                            Text(verbatim: subject.title)
                        } icon: {
                            Image(systemName: subject.icon)
                                .foregroundStyle(Color(hex: subject.colorHex))
                        }
                    }
                    .disabled(settings.isSubjectEnabled(subject.id) && settings.isLastEnabledSubject(subject.id, available: subjectIDs))
                }
            } header: {
                Text("editor.subjects")
            } footer: {
                Text("editor.subjects.footer")
            }

            Section("editor.roundLength") {
                Picker("editor.roundLength", selection: $settings.roundLength) {
                    ForEach(ProfileSettings.roundLengthChoices, id: \.self) { length in
                        Text(verbatim: "\(length)").tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                Toggle("editor.sound", isOn: $settings.soundEnabled)
                Toggle("editor.readAloud", isOn: $settings.readAloudEnabled)
                Toggle("editor.haptics", isOn: $settings.hapticsEnabled)
                if settings.allowsGentleTimer {
                    Toggle("editor.timer", isOn: $settings.gentleTimerEnabled)
                }
            } header: {
                Text("editor.options")
            } footer: {
                if settings.allowsGentleTimer {
                    Text("editor.timer.footer")
                }
            }

            if let profile {
                progressSection(for: profile)
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
            if profile == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("editor.save") { save() }
                    .disabled(!settings.isValid)
                    .accessibilityIdentifier("editor-save")
            }
        }
        .confirmationDialog("editor.reset.confirm", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("editor.reset.action", role: .destructive) {
                if let profile { ProfileMaintenance.resetProgress(of: profile, in: modelContext) }
            }
        }
        .confirmationDialog(Text("editor.delete.confirm \(settings.trimmedName)"), isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("editor.delete.action", role: .destructive) {
                if let profile {
                    ProfileMaintenance.delete(profile, in: modelContext)
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            if let profile { settings = ProfileSettings(profile: profile) }
        }
    }

    // MARK: Sections

    private func progressSection(for profile: ChildProfile) -> some View {
        Section("editor.progress") {
            LabeledContent {
                Text("home.stars \(profile.totalStars)")
            } label: {
                Label("editor.stars", systemImage: "star.fill")
            }
            LabeledContent {
                Text("home.subject.rounds \(profile.rounds.count)")
            } label: {
                Label("editor.rounds", systemImage: "checkmark.circle")
            }
            Button("editor.reset", role: .destructive) { confirmsReset = true }
            Button("editor.delete", role: .destructive) { confirmsDelete = true }
                .accessibilityIdentifier("editor-delete")
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(Palette.avatarColors, id: \.key) { entry in
                Button {
                    settings.avatarColor = entry.key
                } label: {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if settings.avatarColor == entry.key {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("color." + entry.key)))
                .accessibilityAddTraits(settings.avatarColor == entry.key ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: Bindings

    private var languageBinding: Binding<String> {
        Binding(
            get: { settings.learningLanguage },
            set: { settings.setLearningLanguage($0) }
        )
    }

    private func subjectBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { settings.isSubjectEnabled(id) },
            set: { settings.setSubject(id, enabled: $0, available: subjectIDs) }
        )
    }

    // MARK: Saving

    private func save() {
        guard settings.isValid else { return }
        let saved: ChildProfile
        if let profile {
            settings.apply(to: profile)
            saved = profile
        } else {
            saved = settings.makeProfile()
            modelContext.insert(saved)
        }
        try? modelContext.save()
        onSave(saved)
        dismiss()
    }
}
