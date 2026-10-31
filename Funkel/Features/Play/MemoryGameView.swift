import SwiftUI

/// Flip two cards; matching pictures stay open. A cleared board deals a new,
/// slightly bigger one. Mirrors web/src/ui/play/MemoryGame.tsx.
struct MemoryGameView: View {
    let age: Int
    let running: Bool
    let effects: GameEffects
    let addPoints: (Int) -> Void

    @State private var board: [MemoryCard]
    @State private var open: [Int] = []
    @State private var matched: Set<Int> = []
    @State private var busy = false
    @State private var cleared = 0

    private static let spacing: CGFloat = 10

    init(age: Int, running: Bool, effects: GameEffects, addPoints: @escaping (Int) -> Void) {
        self.age = age
        self.running = running
        self.effects = effects
        self.addPoints = addPoints
        var rng = SystemRandomNumberGenerator()
        _board = State(initialValue: Memory.board(age: age, using: &rng))
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("game.memory.hint")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let layout = Self.layout(cards: board.count, in: geo.size)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(layout.side), spacing: Self.spacing), count: layout.columns),
                    spacing: Self.spacing
                ) {
                    ForEach(board) { card in
                        let faceUp = open.contains(card.id) || matched.contains(card.id)
                        MemoryCardView(picture: card.picture, faceUp: faceUp, matched: matched.contains(card.id), side: layout.side) {
                            flip(card)
                        }
                    }
                }
                .id(cleared)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    /// The column count that gives the biggest square cards for this space.
    static func layout(cards: Int, in size: CGSize) -> (columns: Int, side: CGFloat) {
        var best = (columns: 4, side: CGFloat(0))
        for columns in 3...10 {
            let rows = Int((Double(cards) / Double(columns)).rounded(.up))
            let width = (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let height = (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let side = min(width, height, 150)
            if side > best.side { best = (columns, side) }
        }
        return (best.columns, max(20, best.side))
    }

    private func flip(_ card: MemoryCard) {
        guard running, !busy, !open.contains(card.id), !matched.contains(card.id) else { return }
        let next = open + [card.id]
        open = next
        guard next.count == 2,
              let a = board.first(where: { $0.id == next[0] }),
              let b = board.first(where: { $0.id == next[1] }) else { return }

        if a.picture == b.picture {
            effects.pop()
            addPoints(1)
            matched.formUnion([a.id, b.id])
            open = []
            if matched.count == board.count { dealNextBoard() }
        } else {
            busy = true
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                open = []
                busy = false
            }
        }
    }

    /// Board cleared: deal a fresh, slightly bigger one.
    private func dealNextBoard() {
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            var rng = SystemRandomNumberGenerator()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                cleared += 1
                board = Memory.board(age: age, boardsCleared: cleared, using: &rng)
                matched = []
                open = []
            }
        }
    }
}

private struct MemoryCardView: View {
    let picture: String
    let faceUp: Bool
    let matched: Bool
    let side: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(matched ? Color(hex: "#E3F7EC") : .white)
                    .overlay {
                        Text(verbatim: picture).font(.system(size: side * 0.55))
                    }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(faceUp ? 1 : 0)
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(LinearGradient(colors: [Color(hex: "#9B7BF7"), Color(hex: "#6E46DB")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Text(verbatim: "✦")
                            .font(.system(size: side * 0.35, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .opacity(faceUp ? 0 : 1)
            }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 3)
            .rotation3DEffect(.degrees(faceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(matched ? 0.94 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: faceUp)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: matched)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(verbatim: faceUp ? picture : "?"))
        .accessibilityIdentifier("memory-card")
    }
}
