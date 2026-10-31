import SwiftUI

/// Balloons float up; tap to pop. Most children pop only those matching a
/// rule; a wrong one costs a point. Mirrors web/src/ui/play/BalloonPop.tsx.
struct BalloonPopView: View {
    let age: Int
    let running: Bool
    let effects: GameEffects
    let addPoints: (Int) -> Void

    @State private var field: BalloonField
    @State private var touching = false

    init(age: Int, running: Bool, effects: GameEffects, addPoints: @escaping (Int) -> Void) {
        self.age = age
        self.running = running
        self.effects = effects
        self.addPoints = addPoints
        _field = State(initialValue: BalloonField(age: age))
    }

    var body: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            VStack(spacing: 8) {
                hint(for: field.rule)
                if field.rule != .all {
                    Text("game.balloons.penalty")
                        .font(.funkelCaption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    let size = BalloonField.balloonSize(for: geo.size)
                    ZStack {
                        ForEach(field.balloons) { balloon in
                            BalloonView(balloon: balloon, size: size, now: timeline.date)
                                .position(field.center(of: balloon, in: geo.size, balloonSize: size))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(balloon.accessibilityLabel)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { pop(balloon.id) }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(.rect)
                    .gesture(
                        // Pops on touch-down, like the web app: balloons keep moving under the finger.
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !touching else { return }
                                touching = true
                                if let id = field.balloon(at: value.startLocation, in: geo.size, balloonSize: size) { pop(id) }
                            }
                            .onEnded { _ in touching = false }
                    )
                }
                .background(
                    LinearGradient(colors: [Color(hex: "#BFE6FF"), Color(hex: "#E9F6FF")], startPoint: .top, endPoint: .bottom),
                    in: .rect(cornerRadius: Metrics.cardCorner)
                )
                .clipShape(.rect(cornerRadius: Metrics.cardCorner))
            }
            .onChange(of: timeline.date) { _, date in
                if running { field.step(to: date) }
            }
        }
    }

    @ViewBuilder
    private func hint(for rule: BalloonRule) -> some View {
        HStack(spacing: 8) {
            switch rule {
            case .all:
                Text("game.balloons.all")
            case .color(let color):
                Circle().fill(Color(hex: color.hex)).frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey("game.balloons.color." + color.rawValue))
            case .even:
                Text("game.balloons.even")
            case .product(let target):
                Text("game.balloons.product \(target)")
            }
        }
        .font(.funkelHeadline)
        .foregroundStyle(Palette.ink)
        .multilineTextAlignment(.center)
        .animation(.snappy, value: rule)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("balloon-hint")
    }

    private func pop(_ id: Int) {
        guard running, let good = field.pop(id, at: .now) else { return }
        if good {
            effects.pop()
            addPoints(1)
        } else {
            // Tapping everything shouldn't pay off: a wrong balloon bursts grey and costs a point.
            effects.miss()
            addPoints(-1)
        }
    }
}

/// The moving balloons. A plain class stepped by the timeline (not observed:
/// the timeline redraws every frame anyway).
final class BalloonField {
    struct Balloon: Identifiable {
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

        var accessibilityLabel: Text {
            if let label { return Text(verbatim: label) }
            if let colorID { return Text(LocalizedStringKey("game.balloons.name." + colorID.rawValue)) }
            return Text(verbatim: "Ballon")
        }
    }

    private static let colors = ["#FF7A59", "#FFB020", "#3DA5FF", "#34C77B", "#E2558F", "#8A63F2"].map(Color.init(hex:))

    private(set) var rule: BalloonRule
    private(set) var balloons: [Balloon] = []
    private var ruleAge = 0.0
    private var nextID = 0
    private var sinceSpawn = 10.0
    private var lastDate: Date?
    private let spawnEvery: Double
    private let baseSpeed: Double
    private var rng = SystemRandomNumberGenerator()

    init(age: Int) {
        var rng = SystemRandomNumberGenerator()
        rule = Balloons.rule(forAge: age, using: &rng)
        spawnEvery = age < 5 ? 0.9 : age < 7 ? 0.65 : 0.75
        baseSpeed = age < 5 ? 0.13 : age < 7 ? 0.17 : age < 10 ? 0.18 : 0.2
    }

    static func balloonSize(for field: CGSize) -> CGSize {
        let width = min(110, max(64, field.width * 0.13))
        return CGSize(width: width, height: width * 1.2)
    }

    func center(of balloon: Balloon, in field: CGSize, balloonSize: CGSize) -> CGPoint {
        CGPoint(x: balloon.x * field.width, y: field.height * (1 - balloon.y) - balloonSize.height / 2)
    }

    func step(to date: Date) {
        // Keeps pace on slow devices, no jumps after the app was in the background.
        let dt = min(0.1, max(0, date.timeIntervalSince(lastDate ?? date)))
        lastDate = date

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
        balloons.removeAll { balloon in
            if balloon.y >= 1.15 { return true }
            guard let poppedAt = balloon.poppedAt else { return false }
            return date.timeIntervalSince(poppedAt) > (balloon.wrong ? 0.7 : 0.35)
        }
    }

    /// The top-most unpopped balloon under a touch (with a little slack for small fingers).
    func balloon(at point: CGPoint, in field: CGSize, balloonSize: CGSize) -> Int? {
        balloons.last { balloon in
            guard balloon.poppedAt == nil else { return false }
            let c = center(of: balloon, in: field, balloonSize: balloonSize)
            return abs(point.x - c.x) <= balloonSize.width * 0.6 && abs(point.y - c.y) <= balloonSize.height * 0.6
        }?.id
    }

    /// Pops a balloon; returns whether it was a good one (nil if already gone).
    func pop(_ id: Int, at date: Date) -> Bool? {
        guard let i = balloons.firstIndex(where: { $0.id == id }), balloons[i].poppedAt == nil else { return nil }
        balloons[i].poppedAt = date
        balloons[i].wrong = !balloons[i].good
        return balloons[i].good
    }
}

private struct BalloonView: View {
    let balloon: BalloonField.Balloon
    let size: CGSize
    let now: Date

    var body: some View {
        let popped = balloon.poppedAt.map { now.timeIntervalSince($0) }
        let progress = popped.map { min(1, $0 / (balloon.wrong ? 0.7 : 0.35)) } ?? 0
        let fill = balloon.wrong ? Color.gray : balloon.color

        ZStack(alignment: .top) {
            // String
            Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: size.height * 0.98))
                path.addQuadCurve(to: CGPoint(x: size.width / 2, y: size.height * 1.4), control: CGPoint(x: size.width * 0.38, y: size.height * 1.2))
            }
            .stroke(Palette.ink.opacity(0.35), lineWidth: 1.5)
            .opacity(popped == nil ? 1 : 0)

            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [fill.opacity(0.75), fill], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: size.width * 0.7))
                Ellipse()
                    .fill(.white.opacity(0.45))
                    .frame(width: size.width * 0.18, height: size.height * 0.22)
                    .offset(x: -size.width * 0.2, y: -size.height * 0.2)
                if let label = balloon.label {
                    Text(verbatim: label)
                        .font(.system(size: size.width * (label.count > 3 ? 0.26 : 0.34), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(1 + 0.5 * progress)
            .opacity(1 - progress)

            if balloon.wrong {
                Text(verbatim: "−1")
                    .font(.system(size: size.width * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "#C2410C"))
                    .offset(y: size.height * 0.25 - 20 * progress)
                    .opacity(1 - progress * 0.6)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}
