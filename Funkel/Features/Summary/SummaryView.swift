import SwiftUI

/// End of round: stars, score and an encouraging word — never a "fail".
struct SummaryView: View {
    let summary: RoundSummary
    let color: Color
    let profileColor: Color
    let onAgain: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownStars = 0
    @State private var bounce = false

    private var message: LocalizedStringKey {
        switch summary.score {
        case 1...: "summary.message.perfect"
        case 0.8...: "summary.message.great"
        case 0.5...: "summary.message.good"
        default: "summary.message.keepGoing"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Pip(color: profileColor, mood: .cheering)
                    .frame(width: 160, height: 160)
                    .scaleEffect(bounce ? 1 : 0.6)
                    .padding(.top, 40)

                Text("summary.title")
                    .font(.funkelTitle)
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.funkelHeadline)
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Palette.sun)
                            .symbolEffect(.bounce, value: shownStars)
                        Text("summary.stars \(shownStars)")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(Palette.ink)

                    Text("summary.score \(summary.correct) \(summary.total)")
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)

                    if summary.streak > 1 || summary.streakGrew {
                        Label {
                            Text("summary.streak \(summary.streak)")
                        } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                        }
                        .font(.funkelCaption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12), in: .capsule)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .funkelCard()
                .accessibilityElement(children: .combine)

                VStack(spacing: 14) {
                    BigButton(title: "summary.again", systemImage: "arrow.clockwise", color: color, action: onAgain)
                    BigButton(title: "summary.done", systemImage: "house.fill", color: Palette.ink.opacity(0.75), action: onDone)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { bounce = true }
            if reduceMotion {
                shownStars = summary.starsEarned
                return
            }
            for star in 0...summary.starsEarned {
                withAnimation(.snappy) { shownStars = star }
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }
}
