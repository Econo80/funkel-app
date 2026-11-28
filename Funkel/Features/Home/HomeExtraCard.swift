import SwiftUI

/// Where the extra cards on the home screen lead.
enum HomeExtra: String, Identifiable {
    case sudoku, playCorner
    var id: String { rawValue }
}

/// Sizes for the home tiles, worked out from the room the grid has.
struct HomeTileMetrics: Equatable {
    /// The tile height, or nil when the page scrolls and each tile takes what it needs.
    var height: CGFloat?
    /// Side of the white rounded square behind the icon.
    var iconSize: CGFloat

    /// Rows share the height, but never get smaller than this.
    static let minHeight: CGFloat = 96
    /// Tiles on a page that scrolls (a gift card, or very large text).
    static let scrolling = HomeTileMetrics(height: nil, iconSize: 56)
}

/// A home tile (web: `.home-tiles .subject-card`): an icon in a white rounded square,
/// the title and a small subtitle, centred; the progress ring small in the top-right corner.
struct HomeTile<Icon: View>: View {
    let metrics: HomeTileMetrics
    let color: Color
    var progress: Double?
    let title: Text
    let subtitle: Text
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(spacing: 6) {
            icon()
                .font(.system(size: metrics.iconSize * 0.46, weight: .bold))
                .foregroundStyle(color)
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .background(.white, in: .rect(cornerRadius: metrics.iconSize * 0.25))
            VStack(spacing: 2) {
                title
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .lineLimit(2)
                subtitle
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .opacity(0.92)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: metrics.height)
        .frame(minHeight: metrics.height == nil ? 120 : nil)
        .background(color, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .overlay(alignment: .topTrailing) {
            if let progress {
                ProgressRing(progress: progress, lineWidth: 4)
                    .frame(width: 30, height: 30)
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// A home-screen tile that isn't a quiz subject (Denk-Test, Sudoku, Spielecke).
struct HomeExtraCard: View {
    let title: LocalizedStringKey
    let subtitle: Text
    let systemImage: String
    let color: Color
    var metrics: HomeTileMetrics = .scrolling
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HomeTile(metrics: metrics, color: color, title: Text(title), subtitle: subtitle) {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(PressableStyle())
    }
}
