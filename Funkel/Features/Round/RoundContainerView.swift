import SwiftData
import SwiftUI

/// Hosts a round from start to summary, including "play again".
struct RoundContainerView: View {
    let subject: SubjectDescriptor
    let profile: ChildProfile
    /// The weekly Denk-Test: puzzles from easy to hard, a score at the end, no level change.
    var isTest = false

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: RoundViewModel?
    @State private var summary: RoundSummary?
    @State private var testResult: ThinkingTest.Finished?
    @State private var loadFailed = false

    private var speechLocale: String {
        environment.content.language(code: subject.languageCode)?.speechLocale ?? subject.languageCode
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if let testResult {
                TestSummaryView(
                    result: testResult.result,
                    stars: testResult.stars,
                    previous: testResult.previous,
                    color: Color(hex: subject.colorHex),
                    profileColor: Palette.avatarColor(profile.avatarColor),
                    playsSound: profile.soundEnabled,
                    onDone: close
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let summary {
                SummaryView(
                    summary: summary,
                    color: Color(hex: subject.colorHex),
                    profileColor: Palette.avatarColor(profile.avatarColor),
                    playsSound: profile.soundEnabled,
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
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: testResult)
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
            let progress = profile.subjectProgress(for: subject.id, language: subject.languageCode)
            guard let provider = try QuestionProviderFactory.provider(
                for: subject, content: environment.content, country: profile.country, seen: progress?.seenContentIDs ?? []
            ) else {
                loadFailed = true
                return
            }
            // Each subject has its own level (PLAN.md §5.4); recomputed for "play again".
            var difficulty = profile.difficulty(for: subject.id, language: subject.languageCode)
            if let forced = AppLaunch.forcedVocabularyType {
                difficulty.vocabulary.questionTypeWeights = [forced: 1]
            }
            let recent = progress?.recentCorrectContentIDs ?? []
            let questions = isTest
                ? ThinkingTest.makeTest(provider: provider, age: profile.age)
                : provider.makeQuestions(count: profile.roundLength, difficulty: difficulty, recentlyCorrect: Set(recent))
            viewModel = RoundViewModel(subject: subject, questions: questions, difficulty: difficulty, isTest: isTest)
        } catch {
            loadFailed = true
        }
    }

    private func finish() {
        guard summary == nil, testResult == nil, let viewModel, !viewModel.results.isEmpty else { return }
        environment.speech.stop()
        if isTest {
            let previous = profile.thinkingTests.last
            let outcome = viewModel.outcome
            let recorded = ProgressRecorder(context: modelContext).recordThinkingTest(
                points: outcome.correct,
                skills: outcome.skills,
                subjectID: subject.id,
                languageCode: subject.languageCode,
                for: profile
            )
            testResult = ThinkingTest.Finished(result: recorded.result, stars: recorded.stars, previous: previous)
            return
        }
        summary = ProgressRecorder(context: modelContext).record(viewModel.outcome, for: profile)
    }

    private func close() {
        environment.speech.stop()
        dismiss()
    }
}
