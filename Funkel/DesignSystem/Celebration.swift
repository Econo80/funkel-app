import SwiftUI

/// A short burst of confetti, fired each time `trigger` changes.
/// Drawn with Canvas (cheap, no views per particle); hidden from VoiceOver;
/// skipped entirely when Reduce Motion is on.
struct ConfettiBurst: View {
    let trigger: Int
    var colors: [Color] = [Palette.sun, Palette.correct, Color(hex: "#3DA5FF"), Color(hex: "#E2558F"), Color(hex: "#8A63F2")]
    var count = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []
    @State private var startDate: Date?

    private static let lifetime = 1.8
    private static let gravity = 900.0

    struct Particle {
        let angle: Double       // radians, 0 = right, -π/2 = up
        let speed: Double       // points per second
        let spin: Double        // radians per second
        let size: CGFloat
        let colorIndex: Int
        let isCircle: Bool
    }

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let t = timeline.date.timeIntervalSince(startDate)
                guard t < Self.lifetime else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.4)
                let fade = t > Self.lifetime - 0.5 ? (Self.lifetime - t) / 0.5 : 1

                for particle in particles {
                    let x = origin.x + cos(particle.angle) * particle.speed * t
                    let y = origin.y + sin(particle.angle) * particle.speed * t + 0.5 * Self.gravity * t * t
                    var piece = context
                    piece.opacity = fade
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(particle.spin * t))
                    let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2, width: particle.size, height: particle.size * (particle.isCircle ? 1 : 0.5))
                    let path = particle.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    piece.fill(path, with: .color(colors[particle.colorIndex % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { fire() }
    }

    private func fire() {
        guard !reduceMotion else { return }
        particles = (0..<count).map { _ in
            Particle(
                angle: Double.random(in: (-.pi * 0.95)...(-.pi * 0.05)),
                speed: Double.random(in: 380...820),
                spin: Double.random(in: -8...8),
                size: CGFloat.random(in: 7...12),
                colorIndex: Int.random(in: 0..<colors.count),
                isCircle: Bool.random()
            )
        }
        startDate = .now
        Task {
            try? await Task.sleep(for: .seconds(Self.lifetime))
            startDate = nil
        }
    }
}

extension View {
    /// Pip's happy hop: a quick squash-and-stretch with a little wiggle.
    func cheerfulHop(trigger: Int) -> some View {
        modifier(CheerfulHop(trigger: trigger))
    }

    /// A slow, gentle bob so the mascot feels alive on calm screens.
    func idleBob() -> some View {
        modifier(IdleBob())
    }
}

private struct CheerfulHop: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([0.0, 1.0, -0.4, 0.0], trigger: trigger) { view, phase in
                view
                    .scaleEffect(x: 1 - 0.06 * phase, y: 1 + 0.12 * phase, anchor: .bottom)
                    .offset(y: -14 * max(0, phase))
                    .rotationEffect(.degrees(6 * phase))
            } animation: { _ in
                .spring(response: 0.22, dampingFraction: 0.55)
            }
        }
    }
}

private struct IdleBob: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -5 : 0)
            } animation: { _ in
                .easeInOut(duration: 1.6)
            }
        }
    }
}
