import SwiftUI

/// Pip — Funkel's original mascot: a round spark with a three-point tuft,
/// drawn entirely with SwiftUI shapes so it scales and recolours per profile.
struct Pip: View {
    enum Mood {
        case happy, cheering, thinking
    }

    var color: Color
    var mood: Mood = .happy

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                tuft(size: size)
                Circle()
                    .fill(color.gradient)
                    .frame(width: size * 0.8, height: size * 0.8)
                    .shadow(color: color.opacity(0.35), radius: size * 0.06, y: size * 0.04)
                    .offset(y: size * 0.08)
                face(size: size)
                    .offset(y: size * 0.1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func tuft(size: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: size * 0.02) {
            Capsule().frame(width: size * 0.08, height: size * 0.14).rotationEffect(.degrees(-25))
            Capsule().frame(width: size * 0.09, height: size * 0.2)
            Capsule().frame(width: size * 0.08, height: size * 0.14).rotationEffect(.degrees(25))
        }
        .foregroundStyle(color)
        .offset(y: -size * 0.36)
    }

    private func face(size: CGFloat) -> some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.2) {
                eye(size: size)
                eye(size: size)
            }
            mouth(size: size)
        }
        .overlay(alignment: .center) {
            HStack(spacing: size * 0.42) {
                Circle().fill(.pink.opacity(0.35)).frame(width: size * 0.1, height: size * 0.1)
                Circle().fill(.pink.opacity(0.35)).frame(width: size * 0.1, height: size * 0.1)
            }
            .offset(y: size * 0.05)
        }
    }

    @ViewBuilder
    private func eye(size: CGFloat) -> some View {
        switch mood {
        case .cheering:
            // Happy closed eyes: upward arcs.
            PipArc()
                .stroke(Color.black.opacity(0.8), style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * 0.1, height: size * 0.05)
        case .happy, .thinking:
            ZStack(alignment: .topTrailing) {
                Ellipse().fill(Color.black.opacity(0.85)).frame(width: size * 0.09, height: size * 0.12)
                Circle().fill(.white).frame(width: size * 0.035, height: size * 0.035).offset(x: -size * 0.01, y: size * 0.015)
            }
        }
    }

    @ViewBuilder
    private func mouth(size: CGFloat) -> some View {
        switch mood {
        case .thinking:
            Capsule().fill(Color.black.opacity(0.7)).frame(width: size * 0.1, height: size * 0.03)
        case .happy, .cheering:
            PipArc(flipped: true)
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * (mood == .cheering ? 0.2 : 0.16), height: size * 0.07)
        }
    }
}

/// A half-ellipse arc; `flipped` curves downward (a smile).
private struct PipArc: Shape {
    var flipped = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if flipped {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        }
        return path
    }
}

#Preview {
    HStack {
        Pip(color: Palette.sun, mood: .happy)
        Pip(color: Palette.avatarColor("sky"), mood: .cheering)
        Pip(color: Palette.avatarColor("berry"), mood: .thinking)
    }
    .padding()
}
