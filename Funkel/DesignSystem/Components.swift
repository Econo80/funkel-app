import SwiftUI

/// Minimum tap target for small hands (Apple's minimum is 44 pt).
enum Metrics {
    static let minTapSize: CGFloat = 64
    static let cardCorner: CGFloat = 28
    static let buttonCorner: CGFloat = 22
}

// MARK: - Card

struct CardBackground: ViewModifier {
    var color: Color = Palette.card

    func body(content: Content) -> some View {
        content
            .background(color, in: .rect(cornerRadius: Metrics.cardCorner))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

extension View {
    func funkelCard(_ color: Color = Palette.card) -> some View {
        modifier(CardBackground(color: color))
    }
}

// MARK: - Buttons

/// Springy press feedback for every tappable card and button.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A large filled pill button, e.g. "Weiter", "Nochmal".
struct BigButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var color: Color = Palette.sun
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.funkelHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapSize)
            .background(color, in: .rect(cornerRadius: Metrics.buttonCorner))
            .shadow(color: color.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

/// A round icon button for toolbars inside rounds (close, read aloud).
struct CircleIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    // Grows with Dynamic Type, but less than text, so the icon always fits its circle.
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: min(diameter, 72) * 0.4, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: min(diameter, 72), height: min(diameter, 72))
                .background(Palette.card, in: .circle)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Stat chip

/// Small capsule showing an icon and a number, e.g. ⭐️ 120 or 🔥 3.
struct StatChip: View {
    let systemImage: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(value, format: .number)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .font(.funkelHeadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.card, in: .capsule)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = .white

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
