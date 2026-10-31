import SwiftUI

/// Sudoku for the child (placeholder until the Swift port of web/src/ui/Sudoku.tsx lands).
struct SudokuView: View {
    let profile: ChildProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "round.close") { dismiss() }
                    .accessibilityIdentifier("sudoku-close")
                Spacer()
            }
            Spacer()
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Color(hex: "#14A3A3"))
            Text("sudoku.title")
                .font(.funkelTitle)
            Text("port.comingSoon")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}
