import SwiftUI

/// Sounds and haptics for the games, respecting the profile's settings.
struct GameEffects {
    var sound: SoundService?
    var haptics: Bool

    @MainActor func pop() {
        sound?.play(.pop)
        if haptics { Haptics.tap() }
    }

    @MainActor func miss() {
        sound?.play(.gentle)
        if haptics { Haptics.gentle() }
    }
}

/// Wraps a game: a soft 2-minute bar, a point counter and a friendly goodbye.
/// When time is up, Pip suggests a learning round — the game is the treat.
/// Mirrors web/src/ui/play/GameFrame.tsx.
struct GameFrameView: View {
    let profile: ChildProfile
    let game: GameID

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var score = GameScore()
    @State private var running = true
    @State private var startDate = Date.now
    @State private var endDate: Date?
    @State private var celebration = 0

    private var effects: GameEffects {
        GameEffects(sound: profile.soundEnabled ? environment.sound : nil, haptics: profile.hapticsEnabled)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                CircleIconButton(systemImage: "xmark", label: "game.end") { stop() }
                    .accessibilityIdentifier("game-end")
                    .disabled(!running)
                timeBar
                HStack(spacing: 6) {
                    Text(verbatim: "🏅")
                    Text(score.points, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: score.points)
                }
                .font(.funkelHeadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Palette.card, in: .capsule)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("game.points \(score.points)"))
                .accessibilityIdentifier("game-points")
            }
            Text(game.title)
                .font(.funkelHeadline)
                .foregroundStyle(Palette.ink)
            gameView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Palette.background.ignoresSafeArea())
        .overlay {
            if !running { goodbye }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: running)
        .task {
            try? await Task.sleep(for: .seconds(Games.seconds))
            if !Task.isCancelled { stop() }
        }
    }

    @ViewBuilder
    private var gameView: some View {
        let age = profile.playState.gameAge
        let addPoints: (Int) -> Void = { n in if running { score.add(n) } }
        switch game {
        case .memory:
            MemoryGameView(age: age, running: running, effects: effects, addPoints: addPoints)
        case .balloons:
            BalloonPopView(age: age, running: running, effects: effects, addPoints: addPoints)
        case .stars:
            StarCatcherView(age: age, running: running, color: Palette.avatarColor(profile.avatarColor), effects: effects, addPoints: addPoints)
        }
    }

    private var timeBar: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let elapsed = (endDate ?? timeline.date).timeIntervalSince(startDate)
            let left = max(0, 1 - elapsed / Double(Games.seconds))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.1))
                    Capsule()
                        .fill(Palette.sun)
                        .frame(width: max(0, geo.size.width * left))
                        .animation(.linear(duration: 0.25), value: left)
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }

    private var goodbye: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Pip(color: Palette.avatarColor(profile.avatarColor), mood: .cheering)
                    .frame(width: 110, height: 110)
                    .cheerfulHop(trigger: celebration)
                Text("game.timeUp")
                    .font(.funkelTitle)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Text(verbatim: "🏅")
                    Text("game.points \(score.points)")
                }
                Text("game.goodbye")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                BigButton(title: "play.back", color: Color(hex: "#8A63F2")) { dismiss() }
                    .accessibilityIdentifier("game-done")
            }
            .font(.funkelHeadline)
            .foregroundStyle(Palette.ink)
            .padding(28)
            .frame(maxWidth: 420)
            .funkelCard()
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            ConfettiBurst(trigger: celebration, count: 40)
        }
        .onAppear { celebration += 1 }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func stop() {
        guard running else { return }
        running = false
        endDate = .now
        effects.sound?.play(.finish)
    }
}
