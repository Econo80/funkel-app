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
        case let .buildSequence(tiles, answer):
            SequenceBuilder(tiles: tiles, answerLength: answer.count, viewModel: viewModel, color: color)
        }
    }
}

// MARK: - Multiple choice

private struct ChoiceGrid: View {
    let options: [AnswerOption]
    let correctIndex: Int
    let viewModel: RoundViewModel
    let color: Color

    static let spacing: CGFloat = 14
    static let buttonPadding: CGFloat = 12

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var textSize: CGFloat = 34
    @ScaledMetric(relativeTo: .title2) private var longTextSize: CGFloat = 24
    @State private var gridWidth: CGFloat = 0

    private var texts: [String] { options.filter { $0.emoji == nil }.map(\.text) }
    private var isPictureGrid: Bool { options.allSatisfy { $0.emoji != nil } }
    /// Long answers (definitions, phrases) use the calmer, smaller style.
    private var usesLongStyle: Bool { texts.contains { $0.count > 12 } }

    /// Long answers get one column, words two (or a full-width stack when there
    /// are three), short answers fill the row. Huge text sizes always stack.
    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize { return isPictureGrid ? 2 : 1 }
        let longest = texts.map(\.count).max() ?? 0
        switch longest {
        case 23...: return 1
        case 7...: return options.count == 3 ? 1 : 2
        default: return options.count == 3 ? 3 : 2
        }
    }

    /// One size for the whole grid, measured so the longest word fits a column.
    private var fontSize: CGFloat {
        let columns = CGFloat(columnCount)
        let columnWidth = (gridWidth - Self.spacing * (columns - 1)) / columns - Self.buttonPadding * 2 - 4
        let maxSize = usesLongStyle ? longTextSize : textSize
        return TextFitting.fittingSize(
            for: texts,
            width: columnWidth,
            maxSize: maxSize,
            minSize: min(15, maxSize),
            weight: usesLongStyle ? .semibold : .bold
        )
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columnCount), spacing: Self.spacing) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                ChoiceButton(
                    option: option,
                    state: state(for: index),
                    color: color,
                    fontSize: fontSize,
                    usesLongStyle: usesLongStyle
                ) {
                    viewModel.choose(optionIndex: index)
                }
                #if DEBUG
                // Lets UI tests pick a right or wrong answer. Debug builds only.
                .accessibilityIdentifier(index == correctIndex ? "answer-correct" : "answer-wrong")
                #endif
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { gridWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in gridWidth = width }
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
    let fontSize: CGFloat
    let usesLongStyle: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 30
    @ScaledMetric(relativeTo: .largeTitle) private var pictureSize: CGFloat = 60
    @ScaledMetric(relativeTo: .largeTitle) private var minHeight: CGFloat = 92

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
                .padding(ChoiceGrid.buttonPadding)
                .frame(maxWidth: .infinity, minHeight: minHeight)
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
        .accessibilityLabel(Text(verbatim: option.text))
        .accessibilityAddTraits(state == .correct || state == .revealed ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        if let emoji = option.emoji {
            // One emoji = a picture answer; several = a group to count.
            Text(verbatim: emoji)
                .font(.system(size: emoji.count == 1 ? pictureSize : emojiSize))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        } else {
            Text(verbatim: option.text)
                .font(.system(size: fontSize, weight: usesLongStyle ? .semibold : .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(usesLongStyle ? 5 : 3)
                // Safety net only; fontSize is already measured to fit.
                .minimumScaleFactor(0.9)
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
                .accessibilityHidden(true)
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

// MARK: - Letter / word tiles

/// Tap tiles to fill the slots in order; tap a placed tile to take it back.
private struct SequenceBuilder: View {
    let tiles: [String]
    let answerLength: Int
    let viewModel: RoundViewModel
    let color: Color

    @ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = 52

    private var isLetters: Bool { tiles.allSatisfy { $0.count == 1 } }

    private var slotColumns: [GridItem] {
        isLetters
            ? [GridItem(.adaptive(minimum: tileSize, maximum: tileSize + 8), spacing: 8)]
            : [GridItem(.adaptive(minimum: 90), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Slots
            LazyVGrid(columns: slotColumns, spacing: 8) {
                ForEach(0..<answerLength, id: \.self) { position in
                    slot(at: position)
                }
            }
            .padding(14)
            .funkelCard()

            // Tile pool
            LazyVGrid(columns: slotColumns, spacing: 10) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    let used = viewModel.placedTileIndices.contains(index)
                    Button {
                        viewModel.placeTile(index)
                    } label: {
                        tileFace(tile, filled: true)
                    }
                    .buttonStyle(PressableStyle())
                    .opacity(used ? 0.15 : 1)
                    .disabled(used || viewModel.phase != .answering)
                    .accessibilityLabel(Text(verbatim: tile))
                    .accessibilityIdentifier("tile-\(index)")
                }
            }

            BigButton(title: "round.check", systemImage: "checkmark", color: color) {
                viewModel.submitSequence()
            }
            .disabled(!viewModel.canSubmitSequence)
            .opacity(viewModel.canSubmitSequence || viewModel.phase != .answering ? 1 : 0.5)
            .accessibilityIdentifier("sequence-check")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.placedTileIndices)
    }

    @ViewBuilder
    private func slot(at position: Int) -> some View {
        if viewModel.placedTileIndices.indices.contains(position) {
            let tile = tiles[viewModel.placedTileIndices[position]]
            Button {
                viewModel.removePlacedTile(at: position)
            } label: {
                tileFace(tile, filled: true)
            }
            .buttonStyle(PressableStyle())
            .disabled(viewModel.phase != .answering)
            .accessibilityLabel(Text(verbatim: tile))
            .accessibilityHint(Text("round.tile.remove"))
            .transition(.scale.combined(with: .opacity))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                .frame(height: tileSize)
                .accessibilityHidden(true)
        }
    }

    private func tileFace(_ text: String, filled: Bool) -> some View {
        Text(verbatim: text)
            .font(.system(size: isLetters ? tileSize * 0.55 : 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, isLetters ? 0 : 10)
            .frame(maxWidth: .infinity, minHeight: tileSize)
            .background(color, in: .rect(cornerRadius: 14))
            .shadow(color: color.opacity(0.3), radius: 4, y: 2)
    }
}
