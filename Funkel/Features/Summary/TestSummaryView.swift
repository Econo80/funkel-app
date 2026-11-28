import SwiftUI

/// After the Denk-Test: points, the Denk-Niveau, stars, and how it compares
/// with the child's last test (mirrors TestSummary in web/src/ui/Round.tsx).
struct TestSummaryView: View {
    let result: ThinkingTest.Result
    let stars: Int
    let previous: ThinkingTest.Result?
    let color: Color
    let profileColor: Color
    var playsSound = true
    let onDone: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var bounce = false
    @State private var celebration = 0

    private var levelText: String { ProfileEditorView.formatLevelAge(result.levelAge) }

    /// "Letztes Mal: 12 Punkte, Niveau 7½ · besser als letztes Mal!"
    private var previousText: String? {
        guard let previous else { return nil }
        let previousLevelText = ProfileEditorView.formatLevelAge(previous.levelAge)
        let line: String = String(localized: "thinkingTest.previous \(previous.points) \(previousLevelText)")
        let better = result.points > previous.points || result.levelAge > previous.levelAge
        return better ? line + " · " + String(localized: "thinkingTest.better") : line
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Pip(color: profileColor, mood: .cheering)
                    .frame(width: 150, height: 150)
                    .scaleEffect(bounce ? 1 : 0.6)
                    .cheerfulHop(trigger: celebration)
                    .padding(.top, 40)

                Text("thinkingTest.done")
                    .font(.funkelTitle)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Text("thinkingTest.points \(result.points) \(result.total)")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("test-points")

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "🧠")
                            .accessibilityHidden(true)
                        Text("thinkingTest.level \(levelText)")
                    }
                    .font(.funkelHeadline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("test-level")

                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Palette.sun)
                        Text("summary.stars \(stars)")
                    }
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)

                    Group {
                        if let previousText {
                            Text(verbatim: previousText)
                        } else {
                            Text("thinkingTest.first")
                        }
                    }
                    .font(.funkelBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .funkelCard()
                .accessibilityElement(children: .combine)

                BigButton(title: "summary.done", systemImage: "house.fill", color: color, action: onDone)
                    .accessibilityIdentifier("summary-done")
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .overlay {
            ConfettiBurst(trigger: celebration, count: 50)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("test-summary")
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { bounce = true }
            if playsSound { environment.sound.play(.finish) }
            celebration += 1
        }
    }
}
