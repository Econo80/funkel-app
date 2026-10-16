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
        .accessibilityAddTraits(.isHeader)
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
        }
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
