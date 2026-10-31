import SwiftUI

/// Move Pip (finger or arrow keys) to catch stars; clouds make Pip dizzy for
/// a moment. Mirrors web/src/ui/play/StarCatcher.tsx.
struct StarCatcherView: View {
    let age: Int
    let running: Bool
    let color: Color
    let effects: GameEffects
    let addPoints: (Int) -> Void

    @State private var field: StarField
    @FocusState private var focused: Bool

    init(age: Int, running: Bool, color: Color, effects: GameEffects, addPoints: @escaping (Int) -> Void) {
        self.age = age
        self.running = running
        self.color = color
        self.effects = effects
        self.addPoints = addPoints
        _field = State(initialValue: StarField(age: age))
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("game.stars.hint")
                .font(.funkelBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TimelineView(.animation(paused: !running)) { timeline in
                GeometryReader { geo in
                    let pipSize = min(110, max(64, geo.size.width * 0.12))
                    let emojiSize = min(56, max(34, geo.size.width * 0.06))
                    let dizzy = timeline.date < field.dizzyUntil
                    let sparkle = timeline.date.timeIntervalSince(field.sparkleAt) < 0.25
                    ZStack {
                        ForEach(field.fallers) { faller in
                            Text(verbatim: faller.kind == .star ? "⭐" : "🌧️")
                                .font(.system(size: emojiSize))
                                .position(x: faller.x * geo.size.width, y: faller.y * geo.size.height)
                        }
                        Pip(color: color, mood: dizzy ? .thinking : .cheering)
                            .frame(width: pipSize, height: pipSize)
                            .rotationEffect(.degrees(dizzy ? 12 * sin(timeline.date.timeIntervalSinceReferenceDate * 14) : 0))
                            .scaleEffect(sparkle ? 1.12 : 1)
                            .shadow(color: sparkle ? Palette.sun.opacity(0.9) : .clear, radius: 16)
                            .position(x: field.pipX * geo.size.width, y: geo.size.height * StarField.pipY)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard running, geo.size.width > 0 else { return }
                                field.movePip(to: value.location.x / geo.size.width)
                            }
                    )
                }
                .onChange(of: timeline.date) { _, date in
                    guard running else { return }
                    let caught = field.step(to: date)
                    if caught > 0 {
                        effects.pop()
                        addPoints(caught)
                    }
                }
            }
            .background(
                LinearGradient(colors: [Color(hex: "#1B1F4A"), Color(hex: "#3A3F8F")], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: Metrics.cardCorner)
            )
            .clipShape(.rect(cornerRadius: Metrics.cardCorner))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("game.stars.hint"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: field.movePip(to: field.pipX + 0.07)
                case .decrement: field.movePip(to: field.pipX - 0.07)
                @unknown default: break
                }
            }
            // Arrow keys for iPads with a keyboard.
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(.leftArrow) {
                field.movePip(to: field.pipX - 0.07)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                field.movePip(to: field.pipX + 0.07)
                return .handled
            }
            .onAppear { focused = true }
        }
    }
}

/// The falling stars and clouds. A plain class stepped by the timeline.
final class StarField {
    enum Kind { case star, cloud }

    struct Faller: Identifiable {
        let id: Int
        let x: Double        // 0…1 across
        var y: Double        // 0 = top, 1 = bottom
        let speed: Double    // heights per second
        let kind: Kind
    }

    static let catchY = 0.82...0.97
    static let catchWidth = 0.13
    static let pipY = 0.89

    private(set) var pipX = 0.5
    private(set) var fallers: [Faller] = []
    private(set) var dizzyUntil = Date.distantPast
    private(set) var sparkleAt = Date.distantPast
    private var nextID = 0
    private var sinceSpawn = 0.0
    private var lastDate: Date?
    private let speed: Double
    private let cloudShare: Double
    private var rng = SystemRandomNumberGenerator()

    init(age: Int) {
        speed = age < 6 ? 0.22 : age < 9 ? 0.28 : 0.34
        cloudShare = age < 6 ? 0.15 : 0.25
    }

    func movePip(to x: Double) {
        pipX = x.clamped(to: 0.05...0.95)
    }

    /// Moves everything on; returns how many stars Pip caught.
    func step(to date: Date) -> Int {
        let dt = min(0.1, max(0, date.timeIntervalSince(lastDate ?? date)))
        lastDate = date

        sinceSpawn += dt
        if sinceSpawn > 0.7 {
            sinceSpawn = 0
            fallers.append(Faller(
                id: nextID,
                x: Double.random(in: 0.06...0.94, using: &rng),
                y: -0.08,
                speed: speed * Double.random(in: 0.85...1.2, using: &rng),
                kind: Double.random(in: 0..<1, using: &rng) < cloudShare ? .cloud : .star
            ))
            nextID += 1
        }

        let dizzy = date < dizzyUntil
        var caught = 0
        fallers = fallers.compactMap { faller in
            var f = faller
            f.y += f.speed * dt
            let inReach = Self.catchY.contains(f.y) && abs(f.x - pipX) < Self.catchWidth
            if inReach {
                if f.kind == .star && !dizzy {
                    caught += 1
                    sparkleAt = date
                    return nil
                }
                if f.kind == .cloud {
                    dizzyUntil = date.addingTimeInterval(1)   // a short pause, nothing lost
                    return nil
                }
            }
            return f.y < 1.08 ? f : nil
        }
        return caught
    }
}
