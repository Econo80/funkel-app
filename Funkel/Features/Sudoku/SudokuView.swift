import SwiftUI

/// One Sudoku at the child's level; a wrong entry just wobbles, so mistakes
/// never stay on the board (web/src/ui/Sudoku.tsx).
struct SudokuView: View {
    static let color = Color(hex: "#14A3A3")

    let profile: ChildProfile

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var game: SudokuGame?
    @State private var wobble: (cell: Int, count: Int)?
    @State private var celebration = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if let game {
                    Text(game.level.pictures ? "sudoku.rule.pictures" : "sudoku.rule.numbers")
                        .font(.funkelBody)
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    SudokuBoard(game: game, wobble: wobble)
                        .frame(maxWidth: 520)

                    if let earned = game.earned {
                        doneCard(stars: earned)
                    } else {
                        SudokuKeys(game: game, onEnter: enter)
                            .frame(maxWidth: 520)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .overlay {
            ConfettiBurst(trigger: celebration, count: 70)
                .ignoresSafeArea()
        }
        .onAppear {
            if game == nil { game = Self.newGame(for: profile) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemImage: "xmark", label: "round.close") { dismiss() }
                .accessibilityIdentifier("sudoku-close")
            Spacer(minLength: 0)
            (Text(verbatim: "🧩 ") + Text("sudoku.title"))
                .font(.funkelTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            CircleIconButton(systemImage: "lightbulb.fill", label: "sudoku.hint", action: hint)
                .accessibilityIdentifier("sudoku-hint")
                .disabled(game?.isSolved ?? true)
        }
    }

    private func doneCard(stars: Int) -> some View {
        VStack(spacing: 14) {
            Pip(color: Palette.avatarColor(profile.avatarColor), mood: .cheering)
                .frame(width: 84, height: 84)
                .cheerfulHop(trigger: celebration)
            Text("sudoku.solved")
                .font(.funkelTitle)
                .foregroundStyle(Palette.ink)
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Palette.sun)
                    .symbolEffect(.bounce, value: celebration)
                Text("summary.stars \(stars)")
            }
            .font(.funkelHeadline)
            .foregroundStyle(Palette.ink)
            .accessibilityElement(children: .combine)
            BigButton(title: "sudoku.again", systemImage: "arrow.clockwise", color: Self.color, action: restart)
                .accessibilityIdentifier("sudoku-again")
            BigButton(title: "summary.done", systemImage: "house.fill", color: Palette.ink.opacity(0.75)) { dismiss() }
                .accessibilityIdentifier("sudoku-done")
        }
        .padding(24)
        .frame(maxWidth: 520)
        .funkelCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sudoku-solved")
    }

    // MARK: Playing

    private static func newGame(for profile: ChildProfile) -> SudokuGame {
        var rng = SystemRandomNumberGenerator()
        return SudokuGame(age: profile.sudokuAge, using: &rng)
    }

    private func restart() {
        game = Self.newGame(for: profile)
        wobble = nil
    }

    private func enter(_ value: Int) {
        guard let game else { return }
        let cell = game.selected
        handle(game.enter(value), cell: cell)
    }

    private func hint() {
        guard let game else { return }
        handle(game.hint(), cell: game.selected)
    }

    private func handle(_ outcome: SudokuGame.Outcome, cell: Int?) {
        switch outcome {
        case .ignored:
            return
        case .placed:
            if profile.soundEnabled { environment.sound.play(.pop) }
        case .wrong:
            guard let cell else { return }
            wobble = (cell, (wobble?.count ?? 0) + 1)
            let count = wobble?.count
            if profile.soundEnabled { environment.sound.play(.gentle) }
            if profile.hapticsEnabled { Haptics.gentle() }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                if wobble?.count == count { wobble = nil }
            }
        case .solved(let stars):
            ProgressRecorder(context: modelContext).recordSudoku(stars: stars, for: profile)
            if profile.soundEnabled {
                environment.sound.play(.pop)
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    environment.sound.play(.finish)
                }
            }
            if profile.hapticsEnabled { Haptics.correct() }
            celebration += 1
        }
    }
}

// MARK: - Board

/// The grid: thin lines between cells, thick ones around the boxes.
private struct SudokuBoard: View {
    let game: SudokuGame
    let wobble: (cell: Int, count: Int)?

    private var level: SudokuLevel { game.level }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cellSide = side / CGFloat(level.size)
            let related = game.related
            VStack(spacing: 0) {
                ForEach(0..<level.size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<level.size, id: \.self) { col in
                            let cell = row * level.size + col
                            SudokuCell(
                                game: game,
                                cell: cell,
                                isRelated: related.contains(cell),
                                side: cellSide,
                                shake: wobble?.cell == cell ? wobble?.count ?? 0 : 0,
                                isWobbling: wobble?.cell == cell
                            )
                        }
                    }
                }
            }
            .overlay { gridLines(side: side) }
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 4) }
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sudoku-grid")
    }

    private func gridLines(side: CGFloat) -> some View {
        Canvas { context, size in
            let step = size.width / CGFloat(level.size)
            for i in 1..<level.size {
                let offset = CGFloat(i) * step
                var vertical = Path()
                vertical.move(to: CGPoint(x: offset, y: 0))
                vertical.addLine(to: CGPoint(x: offset, y: size.height))
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: offset))
                horizontal.addLine(to: CGPoint(x: size.width, y: offset))
                let thickColumn = i % level.boxCols == 0
                let thickRow = i % level.boxRows == 0
                context.stroke(vertical, with: .color(thickColumn ? Palette.ink : Palette.ink.opacity(0.2)), lineWidth: thickColumn ? 3 : 1)
                context.stroke(horizontal, with: .color(thickRow ? Palette.ink : Palette.ink.opacity(0.2)), lineWidth: thickRow ? 3 : 1)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SudokuCell: View {
    let game: SudokuGame
    let cell: Int
    let isRelated: Bool
    let side: CGFloat
    let shake: Int
    let isWobbling: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var level: SudokuLevel { game.level }
    private var value: Int { game.values[cell] }
    private var isSelected: Bool { game.selected == cell }
    private var accent: Color { SudokuView.color }

    private var background: Color {
        if isWobbling { return Palette.reveal.opacity(0.6) }
        if isSelected { return accent.opacity(0.35) }
        if value != 0 && value == game.selectedValue { return accent.opacity(0.22) }
        if isRelated { return accent.opacity(0.09) }
        return .clear
    }

    /// Pictures need a little less room than digits to look the same size.
    private var fontScale: CGFloat { level.pictures ? 0.5 : 0.55 }

    var body: some View {
        Button {
            game.select(cell)
        } label: {
            Text(verbatim: value == 0 ? "" : level.symbol(value))
                .font(.system(size: side * fontScale, weight: .heavy, design: .rounded))
                .foregroundStyle(game.isGiven(cell) ? Palette.ink : accent)
                .frame(width: side, height: side)
                .background(background)
                .background(Palette.card)
                .overlay {
                    if isSelected {
                        Rectangle().strokeBorder(accent, lineWidth: 3)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: 0.0, trigger: shake) { content, x in
            content.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-4, duration: 0.1)
                LinearKeyframe(4, duration: 0.2)
                LinearKeyframe(0, duration: 0.1)
            }
        }
        .accessibilityLabel(value == 0 ? Text("sudoku.cell.empty") : Text(verbatim: level.symbol(value)))
        .accessibilityValue(Text("sudoku.cell.position \(cell / level.size + 1) \(cell % level.size + 1)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sudoku-cell-\(cell)")
    }
}

// MARK: - Keys

/// One key per number or picture; a key greys out once all of its cells are filled.
private struct SudokuKeys: View {
    let game: SudokuGame
    let onEnter: (Int) -> Void

    @ScaledMetric(relativeTo: .title) private var keyHeight: CGFloat = 64

    private var level: SudokuLevel { game.level }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: level.size <= 6 ? level.size : 5)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...level.size, id: \.self) { value in
                let done = game.remaining(value) == 0
                Button {
                    onEnter(value)
                } label: {
                    Text(verbatim: level.symbol(value))
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: max(Metrics.minTapSize, min(keyHeight, 110)))
                        .funkelCard()
                }
                .buttonStyle(PressableStyle())
                .disabled(done)
                .opacity(done ? 0.35 : 1)
                .accessibilityLabel(Text(verbatim: level.symbol(value)))
                .accessibilityIdentifier("sudoku-key-\(value)")
            }
        }
    }
}
