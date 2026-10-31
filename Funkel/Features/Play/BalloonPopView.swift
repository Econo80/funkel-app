import SwiftUI

/// Balloons float up; tap to pop. Most children pop only those matching a
/// rule; a wrong one costs a point. Drawn with a Canvas, one frame at a time.
struct BalloonPopView: View {
    let age: Int
    let controls: GameControls

    @Environment(AppEnvironment.self) private var environment
    @State private var field: BalloonField
    @State private var touching = false

    init(age: Int, controls: GameControls) {
        self.age = age
        self.controls = controls
        _field = State(initialValue: BalloonField(age: age))
    }

    var body: some View {
        VStack(spacing: 8) {
            hint
            GeometryReader { geo in
                TimelineView(.animation(paused: !controls.running)) { timeline in
                    Canvas { context, size in
                        field.draw(in: &context, size: size, now: timeline.date)
                    }
                    .onChange(of: timeline.date) { _, now in
                        field.step(to: now)
                    }
                }
                .background(LinearGradient(colors: [Color(hex: "#BFE6FF"), Color(hex: "#EAF7FF")], startPoint: .top, endPoint: .bottom))
                .clipShape(.rect(cornerRadius: Metrics.cardCorner))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .contentShape(.rect)
                .gesture(
                    // Pops on touch-down, like the web app, so quick taps always count.
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !touching else { return }
                            touching = true
                            tap(at: value.startLocation, size: geo.size)
                        }
                        .onEnded { _ in touching = false }
                )
                .accessibilityElement()
                .accessibilityLabel(Text("game.balloons"))
                .accessibilityIdentifier("balloon-field")
            }
        }
    }

    @ViewBuilder
    private var hint: some View {
        HStack(spacing: 8) {
            if case .color(let color) = field.rule {
                Ellipse()
                    .fill(Color(hex: color.hex))
                    .frame(width: 20, height: 24)
                    .accessibilityHidden(true)
            }
            Text(field.rule.hint)
        }
        .font(.funkelHeadline)
        .foregroundStyle(Palette.ink)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("balloon-hint")
        .animation(.easeInOut, value: field.rule)
        if field.rule != .all {
            Text("game.balloons.penalty")
                .font(.funkelCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func tap(at point: CGPoint, size: CGSize) {
        guard controls.running, let balloon = field.pop(at: point, size: size, now: .now) else { return }
        if balloon.good {
            if controls.sound { environment.sound.play(.pop) }
            controls.addPoints(1)
        } else {
            // Tapping everything shouldn't pay off: a wrong balloon bursts grey and costs a point.
            if controls.sound { environment.sound.play(.gentle) }
            controls.addPoints(-1)
        }
    }
}

private extension BalloonRule {
    var hint: LocalizedStringKey {
        switch self {
        case .all: "game.balloons.all"
        case .color(let color): LocalizedStringKey("game.balloons.color." + color.rawValue)
        case .even: "game.balloons.even"
        case .product(let target): "game.balloons.product \(target)"
        }
    }
}

/// The moving balloons. A plain class: the TimelineView redraws every frame,
/// so only the rule (shown in the hint) needs to be observed.
@Observable
final class BalloonField {
    struct Balloon {
        let id: Int
        var x: Double          // 0…1 across
        var y: Double          // 0 = bottom, 1 = top
        let speed: Double      // heights per second
        let color: Color
        let colorID: BalloonColor?
        let label: String?
        var good: Bool
        var poppedAt: Date?
        /// Popped by mistake: it costs a point.
        var wrong = false
    }

    private(set) var rule: BalloonRule
    @ObservationIgnored private var balloons: [Balloon] = []
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var sinceSpawn = 10.0
    @ObservationIgnored private var ruleAge = 0.0
    @ObservationIgnored private var last: Date?
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    private let spawnEvery: Double
    private let baseSpeed: Double

    private static let colors = ["#FF7A59", "#FFB020", "#3DA5FF", "#34C77B", "#E2558F", "#8A63F2"].map(Color.init(hex:))
    static let bodySize = CGSize(width: 64, height: 78)
    static let stringLength: CGFloat = 28

    init(age: Int) {
        var rng = SystemRandomNumberGenerator()
        rule = Balloons.rule(forAge: age, using: &rng)
        spawnEvery = age < 5 ? 0.9 : age < 7 ? 0.65 : 0.75
        baseSpeed = age < 5 ? 0.13 : age < 7 ? 0.17 : age < 10 ? 0.18 : 0.2
    }

    func step(to now: Date) {
        // Keeps pace on slow devices, no jumps after the app was in the background.
        let dt = min(0.1, max(0, now.timeIntervalSince(last ?? now)))
        last = now

        // The colour rule switches every so often; balloons already up follow the new colour.
        if case .color(let current) = rule {
            ruleAge += dt
            if ruleAge >= Balloons.colorSeconds {
                ruleAge = 0
                let color = Balloons.nextColor(after: current, using: &rng)
                rule = .color(color)
                for i in balloons.indices { balloons[i].good = balloons[i].colorID == color }
            }
        }

        sinceSpawn += dt
        if sinceSpawn >= spawnEvery && balloons.count < 10 {
            sinceSpawn = 0
            let spec = Balloons.spawn(rule, using: &rng)
            balloons.append(Balloon(
                id: nextID,
                x: Double.random(in: 0.08...0.92, using: &rng),
                y: -0.15,
                speed: baseSpeed * Double.random(in: 0.85...1.15, using: &rng),
                color: spec.color.map { Color(hex: $0.hex) } ?? Self.colors.randomElement(using: &rng)!,
                colorID: spec.color,
                label: spec.label,
                good: spec.good
            ))
            nextID += 1
        }
        for i in balloons.indices where balloons[i].poppedAt == nil {
            balloons[i].y += balloons[i].speed * dt
        }
        balloons.removeAll { b in
            if b.y >= 1.15 { return true }
            guard let popped = b.poppedAt else { return false }
            return now.timeIntervalSince(popped) > (b.wrong ? 0.7 : 0.35)
        }
    }

    /// Pops the top-most balloon under the finger (with a little slack for small hands).
    func pop(at point: CGPoint, size: CGSize, now: Date) -> Balloon? {
        let scale = Self.scale(for: size)
        for i in balloons.indices.reversed() where balloons[i].poppedAt == nil {
            let frame = Self.bodyFrame(of: balloons[i], in: size, scale: scale).insetBy(dx: -12, dy: -12)
            guard frame.contains(point) else { continue }
            balloons[i].poppedAt = now
            balloons[i].wrong = !balloons[i].good
            return balloons[i]
        }
        return nil
    }

    // MARK: Drawing

    /// A little bigger on iPad.
    static func scale(for size: CGSize) -> CGFloat {
        min(1.4, max(1, size.width / 520))
    }

    static func bodyFrame(of balloon: Balloon, in size: CGSize, scale: CGFloat) -> CGRect {
        let width = bodySize.width * scale
        let height = bodySize.height * scale
        let bottom = size.height * (1 - balloon.y) - stringLength * scale
        return CGRect(x: balloon.x * size.width - width / 2, y: bottom - height, width: width, height: height)
    }

    func draw(in context: inout GraphicsContext, size: CGSize, now: Date) {
        let scale = Self.scale(for: size)
        for balloon in balloons {
            let body = Self.bodyFrame(of: balloon, in: size, scale: scale)
            let popped = balloon.poppedAt.map { min(1, now.timeIntervalSince($0) / 0.3) }
            let color = balloon.wrong ? Color(hex: "#A7A3B0") : balloon.color

            if popped == nil {
                var string = Path()
                string.move(to: CGPoint(x: body.midX, y: body.maxY))
                string.addCurve(
                    to: CGPoint(x: body.midX, y: body.maxY + Self.stringLength * scale),
                    control1: CGPoint(x: body.midX - 6, y: body.maxY + 10 * scale),
                    control2: CGPoint(x: body.midX + 6, y: body.maxY + 18 * scale)
                )
                context.stroke(string, with: .color(Color(hex: "#2B2540").opacity(0.35)), lineWidth: 2)
            }

            var layer = context
            if let popped {
                // Bursts: grows and fades.
                let grow = 1 + 0.6 * popped
                layer.opacity = 1 - popped
                layer.translateBy(x: body.midX, y: body.midY)
                layer.scaleBy(x: grow, y: grow)
                layer.translateBy(x: -body.midX, y: -body.midY)
            }
            var knot = Path()
            knot.move(to: CGPoint(x: body.midX, y: body.maxY - 2))
            knot.addLine(to: CGPoint(x: body.midX - 6 * scale, y: body.maxY + 6 * scale))
            knot.addLine(to: CGPoint(x: body.midX + 6 * scale, y: body.maxY + 6 * scale))
            knot.closeSubpath()
            layer.fill(knot, with: .color(color))
            layer.fill(Path(ellipseIn: body), with: .color(color))
            // Soft shade at the bottom right and a shine at the top left.
            layer.fill(Path(ellipseIn: body.insetBy(dx: body.width * 0.12, dy: body.height * 0.1).offsetBy(dx: body.width * 0.1, dy: body.height * 0.1)),
                       with: .color(.black.opacity(0.06)))
            layer.fill(Path(ellipseIn: body), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.6), .white.opacity(0)]),
                center: CGPoint(x: body.minX + body.width * 0.35, y: body.minY + body.height * 0.3),
                startRadius: 0, endRadius: body.width * 0.32
            ))
            if let label = balloon.label {
                var text = layer
                text.addFilter(.shadow(color: .black.opacity(0.35), radius: 1.5, y: 1))
                text.draw(
                    Text(verbatim: label).font(.system(size: 19 * scale, weight: .heavy, design: .rounded)).foregroundStyle(.white),
                    at: CGPoint(x: body.midX, y: body.midY)
                )
            }

            if balloon.wrong, let poppedAt = balloon.poppedAt {
                let t = min(1, now.timeIntervalSince(poppedAt) / 0.7)
                var minus = context
                minus.opacity = 1 - t
                minus.draw(
                    Text(verbatim: "−1").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(Color(hex: "#E5484D")),
                    at: CGPoint(x: body.midX, y: body.minY + 20 - 36 * t)
                )
            }
        }
    }
}
