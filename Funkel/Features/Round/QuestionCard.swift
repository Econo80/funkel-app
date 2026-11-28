import SwiftUI

/// The prompt plus its picture, count objects or equation.
struct QuestionCard: View {
    let question: Question
    let color: Color

    var body: some View {
        VStack(spacing: 18) {
            if let visual = question.visual {
                QuestionVisualView(visual: visual, color: color)
            }
            Text(question.prompt)
                .font(.funkelQuestion)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let sentence = question.sentence {
                Text(sentence)
                    .font(.funkelHeadline)
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .funkelCard()
        .accessibilityElement(children: .combine)
        .modifier(SpokenLabel(text: spokenLabel))
        .accessibilityAddTraits(.isHeader)
    }

    /// VoiceOver reads the same words as read-aloud ("3 plus 4", not "3 · 4").
    /// Counting questions keep the combined label so the objects are read out.
    private var spokenLabel: String? {
        if case .countable? = question.visual { return nil }
        return question.spokenText
    }
}

private struct SpokenLabel: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityLabel(Text(verbatim: text))
        } else {
            content
        }
    }
}

private struct QuestionVisualView: View {
    let visual: QuestionVisual
    let color: Color

    @ScaledMetric(relativeTo: .largeTitle) private var equationSize: CGFloat = 56
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 84

    var body: some View {
        switch visual {
        case let .emoji(emoji):
            Text(emoji)
                .font(.system(size: emojiSize))
                .accessibilityHidden(true)

        case let .equation(text):
            Text(text)
                .font(.system(size: equationSize, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .accessibilityHidden(true)

        case let .countable(symbol, count):
            CountableGrid(symbol: symbol, count: count)

        case let .tiles(items, columns):
            LogicTiles(items: items, columns: columns)
        }
    }
}

/// Denken: pictures in a row that wraps, or a field with `columns` (3×3
/// fields, analogies). The gap "❓" is a dashed purple square; arrows have no
/// background. Sizes follow the web app's `.visual-tiles`.
private struct LogicTiles: View {
    let items: [String]
    let columns: Int?

    private static let purple = Color(hex: "#7B61D9")
    private static let neutral = Color(hex: "#7A7487")

    @ScaledMetric(relativeTo: .largeTitle) private var rowFont: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var rowWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .largeTitle) private var rowHeight: CGFloat = 46
    @ScaledMetric(relativeTo: .largeTitle) private var gridFont: CGFloat = 34
    @ScaledMetric(relativeTo: .largeTitle) private var gridSize: CGFloat = 67
    @ScaledMetric(relativeTo: .largeTitle) private var arrowFont: CGFloat = 26

    /// Fields with two or three pictures per cell (from age 10) get smaller pictures, so three cells fit a phone.
    private var gridScale: CGFloat {
        switch items.map(\.count).max() ?? 1 {
        case ...1: 1
        case 2: 0.8
        default: 0.62
        }
    }

    var body: some View {
        Group {
            if let columns, columns > 0 {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                        GridRow {
                            ForEach(start..<min(start + columns, items.count), id: \.self) { index in
                                tile(items[index], inGrid: true)
                            }
                        }
                    }
                }
            } else {
                CenteredFlow(spacing: 6) {
                    ForEach(items.indices, id: \.self) { index in
                        tile(items[index], inGrid: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .accessibilityIdentifier("logic-tiles")
    }

    @ViewBuilder
    private func tile(_ item: String, inGrid: Bool) -> some View {
        let isGap = item == LogicPuzzleGenerator.missing
        let isArrow = item == LogicPuzzleGenerator.arrow
        Text(verbatim: item)
            .font(.system(size: isArrow ? arrowFont : (inGrid ? gridFont * gridScale : rowFont)))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 4)
            .frame(minWidth: inGrid ? gridSize : rowWidth, minHeight: inGrid ? gridSize : rowHeight)
            .background {
                if !isArrow {
                    RoundedRectangle(cornerRadius: 12)
                        .fill((isGap ? Self.purple : Self.neutral).opacity(0.08))
                }
            }
            .overlay {
                if isGap {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Self.purple, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
                }
            }
    }
}

/// A row that wraps onto more lines, each line centred (CSS `flex-wrap` with
/// `justify-content: center`).
private struct CenteredFlow: Layout {
    var spacing: CGFloat

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let found = lines(for: subviews, width: proposal.width ?? .infinity)
        let width = found.map(\.width).max() ?? 0
        let height = found.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, found.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + spacing
        }
    }

    private func lines(for subviews: Subviews, width: CGFloat) -> [Line] {
        var result: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty && current.width + spacing + size.width > width {
                result.append(current)
                current = Line()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }
}

/// Objects to count, popping in one by one.
private struct CountableGrid: View {
    let symbol: String
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var size: CGFloat {
        switch count {
        case ...5: 56
        case ...10: 46
        default: 38
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: size + 8), spacing: 8)], spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Text(symbol)
                    .font(.system(size: size))
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.06), value: appeared)
            }
        }
        .frame(maxWidth: 360)
        .onAppear { appeared = true }
    }
}
