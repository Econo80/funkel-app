import SwiftUI

/// Chooses the input for a question's format.
struct AnswerArea: View {
    let question: Question
    let viewModel: RoundViewModel
    let color: Color

    var body: some View {
        switch question.format {
        case let .multipleChoice(options, correctIndex):
            ChoiceGrid(options: options, correctIndex: correctIndex, viewModel: viewModel, color: color)
        case .numberEntry:
            NumberPad(viewModel: viewModel, color: color)
        case .buildSequence:
            // Arrives with vocabulary spelling (milestone 4).
            EmptyView()
        }
    }
}

// MARK: - Multiple choice

private struct ChoiceGrid: View {
    let options: [AnswerOption]
    let correctIndex: Int
    let viewModel: RoundViewModel
    let color: Color

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: options.count == 3 ? 3 : 2)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                ChoiceButton(option: option, state: state(for: index), color: color) {
                    viewModel.choose(optionIndex: index)
                }
                #if DEBUG
                // Lets UI tests pick a right or wrong answer. Debug builds only.
                .accessibilityIdentifier(index == correctIndex ? "answer-correct" : "answer-wrong")
                #endif
            }
        }
    }

    private func state(for index: Int) -> ChoiceButton.AnswerState {
        guard case let .feedback(isCorrect) = viewModel.phase else { return .idle }
        if index == correctIndex { return isCorrect ? .correct : .revealed }
        if index == viewModel.selectedOptionIndex { return .chosenWrong }
        return .dimmed
    }
}

private struct ChoiceButton: View {
    enum AnswerState { case idle, correct, revealed, chosenWrong, dimmed }

    let option: AnswerOption
    let state: AnswerState
    let color: Color
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var textSize: CGFloat = 34
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 30

    private var background: Color {
        switch state {
        case .correct: Palette.correct
        case .revealed: Palette.reveal
        case .idle, .chosenWrong, .dimmed: Palette.card
        }
    }

    private var foreground: Color {
        switch state {
        case .correct: .white
        case .revealed: Palette.ink
        case .idle, .chosenWrong, .dimmed: color
        }
    }

    var body: some View {
        Button(action: action) {
            content
                .foregroundStyle(foreground)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(background, in: .rect(cornerRadius: Metrics.buttonCorner))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.buttonCorner)
                        .strokeBorder(color.opacity(state == .idle ? 0.25 : 0), lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
                .overlay(alignment: .topTrailing) { badge }
                .opacity(state == .dimmed || state == .chosenWrong ? 0.45 : 1)
                .scaleEffect(state == .correct ? 1.05 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: state)
        }
        .buttonStyle(PressableStyle())
        .disabled(state != .idle)
        .accessibilityLabel(Text(option.text))
        .accessibilityAddTraits(state == .correct || state == .revealed ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if let emoji = option.emoji {
            Text(emoji)
                .font(.system(size: emojiSize))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        } else {
            Text(option.text)
                .font(.system(size: textSize, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        }
    }

    @ViewBuilder
    private var badge: some View {
        if state == .correct || state == .revealed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(state == .correct ? .white : Palette.ink)
                .padding(8)
                .transition(.scale)
        }
    }
}

// MARK: - Number pad

private struct NumberPad: View {
    let viewModel: RoundViewModel
    let color: Color

    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 44

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 14) {
            Text(viewModel.numberInput.isEmpty ? "?" : viewModel.numberInput)
                .font(.system(size: displaySize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(viewModel.numberInput.isEmpty ? Color.secondary : color)
                .frame(maxWidth: .infinity, minHeight: 76)
                .funkelCard()
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.numberInput)
                .accessibilityLabel(Text(viewModel.numberInput.isEmpty ? "?" : viewModel.numberInput))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...9, id: \.self) { digit in
                    key(Text(String(digit)), label: Text(String(digit))) { viewModel.appendDigit(digit) }
                        .accessibilityIdentifier("key-\(digit)")
                }
                if viewModel.difficulty.maths.allowsNegativeResults {
                    key(Text(verbatim: "±"), label: Text("round.sign")) { viewModel.toggleSign() }
                } else {
                    Color.clear.frame(height: Metrics.minTapSize)
                }
                key(Text(verbatim: "0"), label: Text(verbatim: "0")) { viewModel.appendDigit(0) }
                key(Image(systemName: "delete.left.fill"), label: Text("round.delete")) { viewModel.deleteDigit() }
            }
            .disabled(viewModel.phase != .answering)

            BigButton(title: "round.check", systemImage: "checkmark", color: color) {
                viewModel.submitNumber()
            }
            .accessibilityIdentifier("key-check")
            .disabled(!viewModel.canSubmitNumber)
            .opacity(viewModel.canSubmitNumber || viewModel.phase != .answering ? 1 : 0.5)
        }
    }

    private func key(_ face: some View, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            face
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapSize)
                .funkelCard()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}
