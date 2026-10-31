import SwiftUI

/// Where the extra cards on the home screen lead.
enum HomeExtra: String, Identifiable {
    case sudoku, playCorner
    var id: String { rawValue }
}

/// A home-screen card that isn't a quiz subject (Sudoku, Spielecke).
struct HomeExtraCard: View {
    let title: LocalizedStringKey
    let subtitle: Text
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 72, height: 72)
                    .background(.white, in: .rect(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.funkelHeadline)
                    subtitle
                        .font(.funkelBody)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: .rect(cornerRadius: 28))
        }
        .buttonStyle(PressableStyle())
    }
}
