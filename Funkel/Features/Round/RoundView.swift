import SwiftUI

/// One question per screen, big answer targets, gentle feedback.
struct RoundView: View {
    let viewModel: RoundViewModel
    let profile: ChildProfile
    let speechLocale: String
    let onClose: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var correctPhrase: LocalizedStringKey = "feedback.correct.1"

    private static let correctPhrases: [LocalizedStringKey] = [
        "feedback.correct.1", "feedback.correct.2", "feedback.correct.3", "feedback.correct.4", "feedback.correct.5",
    ]

    private var color: Color { Color(hex: viewModel.subject.colorHex) }

    private var showsTimer: Bool {
        profile.gentleTimerEnabled && viewModel.difficulty.allowsGentleTimer
    }

    var body: some View {
        VStack(spacing: 12) {
            topBar
            if let question = viewModel.current {
                ScrollView {
                    VStack(spacing: 20) {
                        QuestionCard(question: question, color: color)
                        AnswerArea(question: question, viewModel: viewModel, color: color)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(question.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.index)
        .safeAreaInset(edge: .bottom) {
            FeedbackBar(
                phase: viewModel.phase,
                correctPhrase: correctPhrase,
                correctAnswer: viewModel.current?.format.correctAnswerText ?? "",
                explanation: viewModel.current?.explanation,
                profileColor: Palette.avatarColor(profile.avatarColor),
                onNext: { viewModel.next() }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.phase)
        }
        .onChange(of: viewModel.index, initial: true) {
            if profile.readAloudEnabled { readAloud() }
        }
        .onChange(of: viewModel.phase) { _, phase in
            handle(phase)
        }
        .onDisappear { environment.speech.stop() }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CircleIconButton(systemImage: "xmark", label: "round.close", action: onClose)
                ProgressDots(results: viewModel.results, total: viewModel.questions.count, color: color)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("round.progress \(viewModel.questionNumber) \(viewModel.questions.count)"))
                CircleIconButton(systemImage: "speaker.wave.2.fill", label: "round.readAloud", action: readAloud)
            }
            if showsTimer, viewModel.phase == .answering, let question = viewModel.current {
                GentleTimerBar(seconds: viewModel.difficulty.timerSeconds, color: color)
                    .id(question.id)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Behaviour

    private func readAloud() {
        guard let question = viewModel.current else { return }
        environment.speech.speak(question.spokenText, locale: speechLocale)
    }

    private func handle(_ phase: RoundViewModel.Phase) {
        guard case let .feedback(isCorrect) = phase else { return }
        if isCorrect {
            correctPhrase = Self.correctPhrases.randomElement() ?? "feedback.correct.1"
            if profile.hapticsEnabled { Haptics.correct() }
            let index = viewModel.index
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                if viewModel.index == index, viewModel.phase == .feedback(isCorrect: true) {
                    viewModel.next()
                }
            }
        } else if profile.hapticsEnabled {
            Haptics.gentle()
        }
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let results: [Bool]
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(height: index == results.count ? 14 : 10)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3), value: results)
    }

    private func fill(for index: Int) -> Color {
        if index < results.count { return results[index] ? Palette.correct : Palette.reveal }
        if index == results.count { return color }
        return Color.secondary.opacity(0.2)
    }
}

// MARK: - Gentle timer

/// A soft bar that empties over the time limit. It never ends the question;
/// it only hints at pace for older children who opted in.
private struct GentleTimerBar: View {
    let seconds: Int
    let color: Color
    @State private var remaining: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * remaining)
                }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.linear(duration: Double(seconds))) { remaining = 0 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Feedback

private struct FeedbackBar: View {
    let phase: RoundViewModel.Phase
    let correctPhrase: LocalizedStringKey
    let correctAnswer: String
    let explanation: String?
    let profileColor: Color
    let onNext: () -> Void

    var body: some View {
        Group {
            switch phase {
            case .feedback(isCorrect: true):
                HStack(spacing: 16) {
                    Pip(color: profileColor, mood: .cheering)
                        .frame(width: 64, height: 64)
                        .transition(.scale.combined(with: .opacity))
                    Text(correctPhrase)
                        .font(.funkelHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundStyle(Palette.sun)
                        .symbolEffect(.bounce, value: correctAnswer)
                }
                .padding(16)
                .funkelCard(Palette.correct)
                .accessibilityElement(children: .combine)

            case .feedback(isCorrect: false):
                VStack(alignment: .leading, spacing: 10) {
                    Text("feedback.wrong.title")
                        .font(.funkelHeadline)
                    Text("feedback.wrong.answer \(correctAnswer)")
                        .font(.funkelBody)
                    if let explanation {
                        Text(explanation)
                            .font(.funkelCaption)
                            .foregroundStyle(Palette.ink.opacity(0.8))
                    }
                    BigButton(title: "round.next", systemImage: "arrow.right", color: Palette.ink, action: onNext)
                        .padding(.top, 4)
                }
                .foregroundStyle(Palette.ink)
                .padding(18)
                .funkelCard(Palette.reveal.opacity(0.95))

            case .answering, .finished:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: 700)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
