import SwiftData
import SwiftUI

/// Hosts a round from start to summary, including "play again".
struct RoundContainerView: View {
    let subject: SubjectDescriptor
    let profile: ChildProfile

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: RoundViewModel?
    @State private var summary: RoundSummary?
    @State private var loadFailed = false

    private var speechLocale: String {
        environment.content.language(code: subject.languageCode)?.speechLocale ?? subject.languageCode
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if let summary {
                SummaryView(
                    summary: summary,
                    color: Color(hex: subject.colorHex),
                    profileColor: Palette.avatarColor(profile.avatarColor),
                    onAgain: start,
                    onDone: close
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let viewModel {
                RoundView(viewModel: viewModel, profile: profile, speechLocale: speechLocale, onClose: close)
                    .transition(.opacity)
            } else if loadFailed {
                VStack(spacing: 24) {
                    ContentUnavailableView("round.error", systemImage: "exclamationmark.triangle")
                    BigButton(title: "summary.done", action: close)
                        .frame(maxWidth: 320)
                }
            } else {
                ProgressView()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: summary)
        .onAppear {
            if viewModel == nil { start() }
        }
        .onChange(of: viewModel?.phase) { _, phase in
            if phase == .finished { finish() }
        }
    }

    private func start() {
        summary = nil
        do {
            guard let provider = try QuestionProviderFactory.provider(for: subject, content: environment.content) else {
                loadFailed = true
                return
            }
            var difficulty = profile.difficulty
            if let forced = AppLaunch.forcedVocabularyType {
                difficulty.vocabulary.questionTypeWeights = [forced: 1]
            }
            let recent = profile.subjectProgress(for: subject.id, language: subject.languageCode)?.recentCorrectContentIDs ?? []
            let questions = provider.makeQuestions(count: profile.roundLength, difficulty: difficulty, recentlyCorrect: Set(recent))
            viewModel = RoundViewModel(subject: subject, questions: questions, difficulty: difficulty)
        } catch {
            loadFailed = true
        }
    }

    private func finish() {
        guard summary == nil, let viewModel, !viewModel.results.isEmpty else { return }
        environment.speech.stop()
        summary = ProgressRecorder(context: modelContext).record(viewModel.outcome, for: profile)
    }

    private func close() {
        environment.speech.stop()
        dismiss()
    }
}
