import SwiftUI
import UIKit

/// One question per screen, big answer targets, gentle feedback.
struct RoundView: View {
    let viewModel: RoundViewModel
    let profile: ChildProfile
    let speechLocale: String
    let onClose: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var correctPhrase = ""
    @State private var celebration = 0

    /// Praise in the UI language. A String (not a key) so it can also be
    /// announced to VoiceOver.
    private static var correctPhrases: [String] {
        [
            String(localized: "feedback.correct.1"), String(localized: "feedback.correct.2"),
            String(localized: "feedback.correct.3"), String(localized: "feedback.correct.4"),
            String(localized: "feedback.correct.5"),
        ]
    }

    /// Learning-language phrasing, for reading the right answer aloud.
    private var phrasing: Phrasing? {
        try? environment.content.phrasing(language: viewModel.subject.languageCode)
    }

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
                celebration: celebration,
                onNext: { viewModel.next() }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.phase)
        }
        .overlay {
            ConfettiBurst(trigger: celebration)
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.index, initial: true) {
            // VoiceOver users hear the question from VoiceOver itself.
            if profile.readAloudEnabled && !UIAccessibility.isVoiceOverRunning { readAloud() }
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
                    .accessibilityIdentifier("round-close")
                ProgressDots(results: viewModel.results, current: viewModel.index, total: viewModel.questions.count, color: color)
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
        guard case let .feedback(isCorrect) = phase, let question = viewModel.current else { return }
        let answer = question.format.correctAnswerText

        if isCorrect {
            correctPhrase = Self.correctPhrases.randomElement() ?? ""
            celebration += 1
            if profile.soundEnabled { environment.sound.play(.correct) }
            if profile.hapticsEnabled { Haptics.correct() }
            announce(correctPhrase)

            // Give VoiceOver time to speak before moving on.
            let delay = UIAccessibility.isVoiceOverRunning ? 2.5 : 1.3
            let index = viewModel.index
            Task {
                try? await Task.sleep(for: .seconds(delay))
                if viewModel.index == index, viewModel.phase == .feedback(isCorrect: true) {
                    viewModel.next()
                }
            }
        } else {
            if profile.soundEnabled { environment.sound.play(.gentle) }
            if profile.hapticsEnabled { Haptics.gentle() }
            announce(String(localized: "feedback.wrong.answer \(answer)"))
            // Pre-readers hear the right answer in the learning language.
            if profile.readAloudEnabled && !UIAccessibility.isVoiceOverRunning, let phrasing {
                environment.speech.speak(phrasing.text("speech.answer", ["answer": answer]), locale: speechLocale)
            }
        }
    }

    private func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning, !text.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let results: [Bool]
    let current: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(height: index == current ? 14 : 10)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3), value: results)
    }

    private func fill(for index: Int) -> Color {
        if index < results.count { return results[index] ? Palette.correct : Palette.reveal }
        if index == current { return color }
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
    let correctPhrase: String
    let correctAnswer: String
    let explanation: String?
    let profileColor: Color
    let celebration: Int
    let onNext: () -> Void

    var body: some View {
        Group {
            switch phase {
            case .feedback(isCorrect: true):
                HStack(spacing: 16) {
                    Pip(color: profileColor, mood: .cheering)
                        .frame(width: 64, height: 64)
                        .cheerfulHop(trigger: celebration)
                        .transition(.scale.combined(with: .opacity))
                    Text(verbatim: correctPhrase)
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
                        .accessibilityIdentifier("round-next")
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
