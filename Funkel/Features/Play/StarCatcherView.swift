import SwiftUI

/// Move Pip (finger or arrow keys) to catch stars; clouds make Pip dizzy for a moment.
struct StarCatcherView: View {
    let age: Int
    let color: Color
    let controls: GameControls

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sky: StarSky
    @FocusState private var focused: Bool

    init(age: Int, color: Color, controls: GameControls) {
        self.age = age
        self.color = color
        self.controls = controls
        _sky = State(initialValue: StarSky(age: age))
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("game.stars.hint")
                .font(.funkelHeadline)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            GeometryReader { geo in
                TimelineView(.animation(paused: !controls.running)) { timeline in
                    let now = timeline.date
                    let pipSize = StarSky.pipSize(for: geo.size)
                    let dizzy = sky.isDizzy(at: now)
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            sky.draw(in: &context, size: size, at: now)
                        }
                        Pip(color: color, mood: dizzy ? .thinking : .cheering)
                            .frame(width: pipSize, height: pipSize)
                            .rotationEffect(.degrees(dizzy && !reduceMotion ? 10 * sin(now.timeIntervalSinceReferenceDate * 12.6) : 0))
                            .shadow(color: Color(hex: "#FFD76A").opacity(sky.isSparkling(at: now) ? 1 : 0), radius: 12)
                            .position(x: sky.pipX * geo.size.width, y: geo.size.height - 8 - pipSize / 2)
                    }
                    .onChange(of: now) { _, now in
                        if sky.step(to: now), controls.running {
                            if controls.sound { environment.sound.play(.pop) }
                            controls.addPoints(1)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(LinearGradient(colors: [Color(hex: "#24305E"), Color(hex: "#4B3F8F")], startPoint: .top, endPoint: .bottom))
                .clipShape(.rect(cornerRadius: Metrics.cardCorner))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard controls.running, geo.size.width > 0 else { return }
                            sky.movePip(to: value.location.x / geo.size.width)
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(Text("game.stars"))
                .accessibilityIdentifier("star-field")
            }
        }
        // Arrow keys for iPads with a keyboard.
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            sky.movePip(to: sky.pipX - 0.07)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            sky.movePip(to: sky.pipX + 0.07)
            return .handled
        }
        .onAppear { focused = true }
    }
}

/// Falling stars and clouds, plus where Pip is. The TimelineView redraws every frame.
final class StarSky {
    struct Faller {
        let id: Int
        let x: Double          // 0…1 across
        var y: Double          // 0 = top, 1 = bottom
        let speed: Double      // heights per second
        let isStar: Bool
    }

    private(set) var pipX = 0.5
    private var fallers: [Faller] = []
    private var nextID = 0
    private var sinceSpawn = 0.0
    private var last: Date?
    private var dizzyUntil = Date.distantPast
    private var sparkleAt = Date.distantPast
    private var rng = SystemRandomNumberGenerator()
    private let speed: Double
    private let cloudShare: Double

    private static let catchY = 0.82...0.97
    private static let catchWidth = 0.13

    init(age: Int) {
        speed = age < 6 ? 0.22 : age < 9 ? 0.28 : 0.34
        cloudShare = age < 6 ? 0.15 : 0.25
    }

    static func pipSize(for size: CGSize) -> CGFloat {
        72 * min(1.4, max(1, size.width / 520))
    }

    func movePip(to x: Double) {
        pipX = min(0.95, max(0.05, x))
    }

    func isDizzy(at now: Date) -> Bool { now < dizzyUntil }
    func isSparkling(at now: Date) -> Bool { now.timeIntervalSince(sparkleAt) < 0.25 }

    /// Moves everything on; true when Pip caught a star.
    func step(to now: Date) -> Bool {
        let dt = min(0.1, max(0, now.timeIntervalSince(last ?? now)))
        last = now

        sinceSpawn += dt
        if sinceSpawn > 0.7 {
            sinceSpawn = 0
            fallers.append(Faller(
                id: nextID,
                x: Double.random(in: 0.06...0.94, using: &rng),
                y: -0.08,
                speed: speed * Double.random(in: 0.85...1.2, using: &rng),
                isStar: Double.random(in: 0..<1, using: &rng) >= cloudShare
            ))
            nextID += 1
        }

        let dizzy = isDizzy(at: now)
        var caught = false
        fallers = fallers.compactMap { faller in
            var f = faller
            f.y += f.speed * dt
            if Self.catchY.contains(f.y) && abs(f.x - pipX) < Self.catchWidth {
                if f.isStar && !dizzy {
                    caught = true
                    sparkleAt = now
                    return nil
                }
                if !f.isStar {
                    dizzyUntil = now.addingTimeInterval(1)   // a short pause, nothing lost
                    return nil
                }
            }
            return f.y < 1.08 ? f : nil
        }
        return caught
    }

    /// `now` only ties the drawing to the frame, so the Canvas redraws every tick.
    func draw(in context: inout GraphicsContext, size: CGSize, at now: Date) {
        let fontSize = 35 * min(1.4, max(1, size.width / 520))
        let star = context.resolve(Text(verbatim: "⭐").font(.system(size: fontSize)))
        let cloud = context.resolve(Text(verbatim: "🌧️").font(.system(size: fontSize)))
        for f in fallers {
            context.draw(f.isStar ? star : cloud, at: CGPoint(x: f.x * size.width, y: f.y * size.height))
        }
    }
}
