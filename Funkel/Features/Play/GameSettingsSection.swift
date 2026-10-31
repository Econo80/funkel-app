import SwiftUI

/// The play corner's settings in the profile editor; written back on "Speichern".
struct GameSettings: Equatable {
    var enabled = true
    var cost = 10
    var perDay = 3
    var difficulty: GameDifficulty = .normal

    init() {}

    init(profile: ChildProfile) {
        let state = profile.playState
        enabled = state.gamesEnabled
        cost = state.gameCost
        perDay = state.gamesPerDay
        difficulty = state.gameDifficulty
    }

    func apply(to profile: ChildProfile) {
        profile.setGameSettings(enabled: enabled, cost: cost, perDay: perDay, difficulty: difficulty)
    }
}

/// "Spielecke": on/off, price per game, difficulty and games per day.
struct GameSettingsSection: View {
    @Binding var settings: GameSettings

    var body: some View {
        Section {
            Toggle("editor.games.enabled", isOn: $settings.enabled)
                .accessibilityIdentifier("games-enabled")
            if settings.enabled {
                Picker("editor.games.cost", selection: $settings.cost) {
                    // A cost from the web app that isn't one of the choices stays selectable.
                    ForEach(choices(Games.costChoices, keeping: settings.cost), id: \.self) { cost in
                        Text(verbatim: "\(cost) ★").tag(cost)
                    }
                }
                Picker("editor.games.difficulty", selection: $settings.difficulty) {
                    ForEach(GameDifficulty.allCases) { difficulty in
                        Text(LocalizedStringKey("editor.games.difficulty." + difficulty.rawValue)).tag(difficulty)
                    }
                }
                .accessibilityIdentifier("games-difficulty")
                Picker("editor.games.perDay", selection: $settings.perDay) {
                    ForEach(choices(Games.perDayChoices, keeping: settings.perDay), id: \.self) { count in
                        Text(verbatim: count == 0 ? "∞" : "\(count)").tag(count)
                    }
                }
            }
        } header: {
            Label("editor.games", systemImage: "gamecontroller.fill")
        } footer: {
            Text("editor.games.footer")
        }
    }

    private func choices(_ base: [Int], keeping current: Int) -> [Int] {
        guard !base.contains(current) else { return base }
        // 0 (no limit) stays last.
        return (base.filter { $0 != 0 } + [current]).sorted() + (base.contains(0) ? [0] : [])
    }
}
