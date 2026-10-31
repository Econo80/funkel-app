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
    /// Per-subject levels changed here (years above/below the age), keyed "lang/subject"; saved with "Speichern".
    @State private var levels: [String: Double] = [:]
    /// Stars to give, added to the wallet on "Speichern".
    @State private var gift = 0

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

            if let profile {
                levelsSection(for: profile)
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

            gamesSection

            if let profile {
                giftSection(for: profile)
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
                if gift > 0 {
                    Text(verbatim: "\(profile.walletStars) → \(profile.walletStars + gift)")
                        .foregroundStyle(Palette.correct)
                } else {
                    Text(verbatim: "\(profile.walletStars)")
                }
            } label: {
                Label("editor.wallet", systemImage: "gamecontroller.fill")
            }
            .accessibilityIdentifier("editor-wallet")
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

    /// − / + per subject, in half years. Shown relative to the age being edited.
    private func levelsSection(for profile: ChildProfile) -> some View {
        Section {
            ForEach(language?.subjects ?? []) { subject in
                let adjustment = levelAdjustment(subject, profile: profile)
                let levelAge = DifficultyScale.effectiveAge(age: settings.age, adjustment: adjustment)
                let levelText = Self.formatLevelAge(levelAge)
                HStack(spacing: 12) {
                    Label {
                        Text(verbatim: subject.title)
                    } icon: {
                        Image(systemName: subject.icon)
                            .foregroundStyle(Color(hex: subject.colorHex))
                    }
                    Spacer(minLength: 8)
                    Button {
                        setLevel(subject, adjustment - 0.5)
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(adjustment <= -DifficultyTuning.maxAdjustment || levelAge <= Double(DifficultyTuning.minAge))
                    .accessibilityLabel(Text("editor.level.easier \(subject.title)"))
                    .accessibilityIdentifier("level-down-\(subject.id)")
                    Text("editor.level \(levelText)")
                        .font(.funkelCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 120)
                    Button {
                        setLevel(subject, adjustment + 0.5)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .buttonStyle(.borderless)
                    .disabled(adjustment >= DifficultyTuning.maxAdjustmentUp || levelAge >= Double(DifficultyTuning.maxAge))
                    .accessibilityLabel(Text("editor.level.harder \(subject.title)"))
                    .accessibilityIdentifier("level-up-\(subject.id)")
                }
                .accessibilityIdentifier("level-\(subject.id)")
            }
        } header: {
            Text("editor.levels")
        } footer: {
            Text("editor.level.footer")
        }
    }

    /// Spielecke: on/off, price per game, difficulty and games per day.
    private var gamesSection: some View {
        Section {
            Toggle("editor.games.enabled", isOn: $settings.gamesEnabled)
                .accessibilityIdentifier("editor-games")
            if settings.gamesEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("editor.games.cost")
                    Picker("editor.games.cost", selection: $settings.gameCost) {
                        ForEach(Self.choices(Games.costChoices, keeping: settings.gameCost), id: \.self) { cost in
                            Text(verbatim: "\(cost) ★").tag(cost)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("editor.games.difficulty")
                    Picker("editor.games.difficulty", selection: $settings.gameDifficulty) {
                        ForEach(GameDifficulty.allCases) { difficulty in
                            Text(LocalizedStringKey("editor.games.difficulty." + difficulty.rawValue)).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("editor-games-difficulty")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("editor.games.perDay")
                    Picker("editor.games.perDay", selection: $settings.gamesPerDay) {
                        ForEach(Self.choices(Games.perDayChoices, keeping: settings.gamesPerDay), id: \.self) { count in
                            Text(verbatim: count == 0 ? "∞" : "\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        } header: {
            Label("editor.games", systemImage: "gamecontroller.fill")
        } footer: {
            Text("editor.games.footer")
        }
    }

    /// The usual choices, plus a value set elsewhere (e.g. a web backup), so the picker never shows nothing selected.
    static func choices(_ choices: [Int], keeping value: Int) -> [Int] {
        choices.contains(value) ? choices : (choices + [value]).sorted { ($0 == 0 ? Int.max : $0) < ($1 == 0 ? Int.max : $1) }
    }

    private func giftSection(for profile: ChildProfile) -> some View {
        Section {
            HStack {
                Text("editor.gift.amount")
                Spacer()
                Button {
                    gift = max(0, gift - 5)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(gift <= 0)
                .accessibilityLabel(Text("editor.gift.less"))
                .accessibilityIdentifier("gift-down")
                Label {
                    Text(verbatim: "\(gift)").monospacedDigit()
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(Palette.sun)
                }
                .font(.funkelHeadline)
                .frame(minWidth: 72)
                .accessibilityIdentifier("gift-amount")
                Button {
                    gift = min(ProfileMaintenance.giftMax, gift + 5)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(gift >= ProfileMaintenance.giftMax)
                .accessibilityLabel(Text("editor.gift.more"))
                .accessibilityIdentifier("gift-up")
            }
            HStack(spacing: 8) {
                ForEach(ProfileMaintenance.giftChoices, id: \.self) { amount in
                    Button {
                        gift = amount
                    } label: {
                        Text(verbatim: "\(amount) ★")
                            .font(.funkelCaption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(gift == amount ? Palette.sun : .secondary)
                    .accessibilityIdentifier("gift-\(amount)")
                }
            }
        } header: {
            Label("editor.gift", systemImage: "gift.fill")
        } footer: {
            if gift > 0 {
                Text("editor.gift.pending \(gift) \(profile.name)")
            } else {
                Text("editor.gift.footer")
            }
        }
    }

    private func levelAdjustment(_ subject: SubjectDescriptor, profile: ChildProfile) -> Double {
        if let changed = levels["\(subject.languageCode)/\(subject.id)"] { return changed }
        // A new age starts every subject from the real age again.
        return settings.age == profile.age ? profile.adaptivity(for: subject.id, language: subject.languageCode).adjustment : 0
    }

    private func setLevel(_ subject: SubjectDescriptor, _ adjustment: Double) {
        levels["\(subject.languageCode)/\(subject.id)"] = ((adjustment * 2).rounded() / 2).clamped(to: DifficultyScale.adjustmentRange)
    }

    /// 8.5 → "8½", rounded to half years.
    static func formatLevelAge(_ age: Double) -> String {
        let half = (age * 2).rounded() / 2
        let whole = Int(half.rounded(.down))
        return half > Double(whole) ? "\(whole)½" : "\(whole)"
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
            for (key, adjustment) in levels {
                let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                ProfileMaintenance.setSubjectAdjustment(adjustment, subjectID: parts[1], language: parts[0], of: profile, in: modelContext)
            }
            ProfileMaintenance.giveStars(gift, to: profile)
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
