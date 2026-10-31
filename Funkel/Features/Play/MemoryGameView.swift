import SwiftUI

/// Flip two cards; matching pictures stay open. A cleared board deals a new, bigger one.
struct MemoryGameView: View {
    let age: Int
    let controls: GameControls

    @Environment(AppEnvironment.self) private var environment
    @State private var board: [MemoryCard] = []
    @State private var open: [Int] = []
    @State private var matched: Set<Int> = []
    @State private var busy = false
    @State private var cleared = 0

    private let spacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 12) {
            Text("game.memory.hint")
                .font(.funkelHeadline)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            GeometryReader { geo in
                let columns = board.count <= 16 ? 4 : board.count <= 24 ? 5 : 6
                let rows = max(1, (board.count + columns - 1) / columns)
                let side = max(30, min(
                    (geo.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                    (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
                ))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: columns), spacing: spacing) {
                    ForEach(board) { card in
                        cardView(card, side: side)
                    }
                }
                .id(cleared)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if board.isEmpty { deal() }
        }
    }

    private func cardView(_ card: MemoryCard, side: CGFloat) -> some View {
        let faceUp = open.contains(card.id) || matched.contains(card.id)
        let isMatched = matched.contains(card.id)
        return Button {
            flip(card)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(faceUp
                        ? AnyShapeStyle(isMatched ? Palette.correct.opacity(0.25) : Palette.card)
                        : AnyShapeStyle(LinearGradient(colors: [Color(hex: "#8A63F2"), Color(hex: "#B28BFF")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .background(Palette.card, in: .rect(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                Text(verbatim: faceUp ? card.picture : "✦")
                    .font(.system(size: side * 0.48))
                    .foregroundStyle(.white)
                    // Mirror the face back, so it reads correctly after the flip.
                    .scaleEffect(x: faceUp ? -1 : 1)
            }
            .frame(width: side, height: side)
            .rotation3DEffect(.degrees(faceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(faceUp ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: faceUp)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(verbatim: faceUp ? card.picture : "?"))
        .accessibilityIdentifier("memory-card")
    }

    private func deal() {
        var rng = SystemRandomNumberGenerator()
        board = Memory.board(age: age, boardsCleared: cleared, using: &rng)
        matched = []
        open = []
    }

    private func flip(_ card: MemoryCard) {
        guard controls.running, !busy, !open.contains(card.id), !matched.contains(card.id) else { return }
        let next = open + [card.id]
        open = next
        guard next.count == 2,
              let a = board.first(where: { $0.id == next[0] }),
              let b = board.first(where: { $0.id == next[1] }) else { return }

        if a.picture == b.picture {
            if controls.sound { environment.sound.play(.pop) }
            controls.addPoints(1)
            matched.formUnion([a.id, b.id])
            open = []
            if matched.count == board.count { nextBoard() }
        } else {
            busy = true
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                open = []
                busy = false
            }
        }
    }

    /// Board cleared: after a short look, deal a fresh, slightly bigger one.
    private func nextBoard() {
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.3)) {
                cleared += 1
                deal()
            }
        }
    }
}
