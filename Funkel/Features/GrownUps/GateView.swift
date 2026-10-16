import SwiftUI

/// Shows the maths gate first and `content` once it's solved.
/// Present it in a sheet: `GrownUpGate { GrownUpsView() }`.
struct GrownUpGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @State private var isUnlocked = false

    var body: some View {
        if isUnlocked {
            content()
                .transition(.opacity)
        } else {
            GateView(
                onUnlock: { withAnimation(.easeInOut(duration: 0.25)) { isUnlocked = true } },
                onCancel: { dismiss() }
            )
        }
    }
}

/// "Nur für Erwachsene": solve 14 × 7 to continue. A wrong answer quietly
/// swaps in a new question.
struct GateView: View {
    let onUnlock: () -> Void
    let onCancel: () -> Void

    @State private var challenge = GateChallenge.random()
    @State private var input = ""
    @State private var showsRetryHint = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .padding(.top, 12)
                        .accessibilityHidden(true)

                    Text("gate.title")
                        .font(.funkelTitle)
                        .foregroundStyle(Palette.ink)
                    Text(showsRetryHint ? LocalizedStringKey("gate.wrong") : LocalizedStringKey("gate.message"))
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("gate.question \(challenge.a) \(challenge.b)")
                        .font(.funkelHeadline)
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("gate-question")

                    Text(input.isEmpty ? "?" : input)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(input.isEmpty ? Color.secondary : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .funkelCard()

                    keypad

                    BigButton(title: "round.check", systemImage: "checkmark", color: Palette.ink, action: check)
                        .disabled(input.isEmpty)
                        .opacity(input.isEmpty ? 0.5 : 1)
                        .accessibilityIdentifier("gate-check")
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel", action: onCancel)
                }
            }
        }
    }

    private var keypad: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { digit in
                key(String(digit)) { append(digit) }
            }
            Color.clear.frame(height: 56)
            key("0") { append(0) }
            Button {
                if !input.isEmpty { input.removeLast() }
            } label: {
                Image(systemName: "delete.left.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .funkelCard()
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text("round.delete"))
        }
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .funkelCard()
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("gate-key-\(label)")
    }

    private func append(_ digit: Int) {
        guard input.count < 4 else { return }
        input.append(String(digit))
    }

    private func check() {
        if challenge.isCorrect(input) {
            onUnlock()
        } else {
            showsRetryHint = true
            input = ""
            challenge = GateChallenge.random()
        }
    }
}
