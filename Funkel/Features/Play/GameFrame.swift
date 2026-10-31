import SwiftUI

/// What a game gets from its frame.
struct GameControls {
    /// False once the time is up; games stop spawning and accepting input.
    let running: Bool
    /// Adds points (negative for a mistake; the score never drops below 0).
    let addPoints: (Int) -> Void
    let sound: Bool
}

/// Wraps a game: a soft 2-minute bar, a point counter and a friendly goodbye.
/// When time is up, Pip suggests a learning round — the game is the treat.
struct GameFrame<Content: View>: View {
    let profile: ChildProfile
    let game: GameID
    @ViewBuilder let content: (GameControls) -> Content

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var points = 0
    @State private var startedAt = Date.now
    @State private var endedAt: Date?
    @State private var celebration = 0

    private var running: Bool { endedAt == nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CircleIconButton(systemImage: "xmark", label: "game.end") { end() }
                    .accessibilityIdentifier("game-end")
                timerBar
                StatChip(systemImage: "medal.fill", value: points, color: Palette.sun)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("game.points \(points)"))
                    .accessibilityIdentifier("game-points")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Text(game.title)
                .font(.funkelHeadline)
                .foregroundStyle(Palette.ink)
                .padding(.top, 12)

            content(GameControls(running: running, addPoints: addPoints, sound: profile.soundEnabled))
                .frame(maxWidth: 700, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .overlay {
            if !running { goodbye }
        }
        .animation(.easeOut(duration: 0.25), value: running)
        .task {
            // Cancelled when the game is closed early: then there is nothing to end.
            guard (try? await Task.sleep(for: .seconds(Games.seconds))) != nil else { return }
            end()
        }
    }

    private var timerBar: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !running)) { timeline in
            let elapsed = (endedAt ?? timeline.date).timeIntervalSince(startedAt)
            let remaining = max(0, 1 - elapsed / Double(Games.seconds))
            GeometryReader { geo in
                Capsule()
                    .fill(Palette.ink.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Palette.sun.opacity(0.6))
                            .frame(width: geo.size.width * remaining)
                    }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var goodbye: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 10) {
                Pip(color: Palette.avatarColor(profile.avatarColor), mood: .cheering)
                    .frame(width: 110, height: 110)
                    .cheerfulHop(trigger: celebration)
                Text("game.timeUp")
                    .font(.funkelTitle)
                    .multilineTextAlignment(.center)
                Text(verbatim: "🏅 ") + Text("game.points \(points)")
                Text("game.goodbye")
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                BigButton(title: "play.back", color: Palette.ink.opacity(0.75)) { dismiss() }
                    .accessibilityIdentifier("game-done")
                    .padding(.top, 8)
            }
            .font(.funkelHeadline)
            .foregroundStyle(Palette.ink)
            .padding(28)
            .frame(maxWidth: 420)
            .funkelCard()
            .padding(20)
            ConfettiBurst(trigger: celebration, count: 40)
                .allowsHitTesting(false)
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("game-over")
        .onAppear { celebration += 1 }
    }

    private func addPoints(_ n: Int) {
        guard running else { return }
        points = max(0, points + n)
    }

    private func end() {
        guard running else { return }
        endedAt = .now
        if profile.soundEnabled { environment.sound.play(.finish) }
    }
}

extension GameID {
    var title: LocalizedStringKey {
        switch self {
        case .memory: "game.memory"
        case .balloons: "game.balloons"
        case .stars: "game.stars"
        }
    }

    var icon: String {
        switch self {
        case .memory: "🃏"
        case .balloons: "🎈"
        case .stars: "⭐"
        }
    }

    var color: Color {
        switch self {
        case .memory: Color(hex: "#8A63F2")
        case .balloons: Color(hex: "#E2558F")
        case .stars: Color(hex: "#3DA5FF")
        }
    }
}
