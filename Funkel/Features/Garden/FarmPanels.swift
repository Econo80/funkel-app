import SwiftUI

// The farm's HUD, bottom bar, drawers and dialogs. The farm is its own little
// world in warm daylight colours, in light and dark mode alike.

enum FarmColors {
    static let ink = Color(hex: "#2b2540")
    static let muted = Color(hex: "#7a7487")
    static let sheet = Color(hex: "#fff8ee")
    static let cardEdge = Color(hex: "#e6dccb")
}

extension View {
    /// A white capsule in the HUD.
    func farmPill(compact: Bool, fill: Color = .white.opacity(0.94)) -> some View {
        font(.system(size: compact ? 15 : 18, weight: .heavy, design: .rounded))
            .foregroundStyle(FarmColors.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, compact ? 8 : 14)
            .padding(.vertical, compact ? 8 : 10)
            .background {
                Capsule().fill(fill).shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            }
    }
}

// MARK: HUD

/// The farm level in a golden badge, and the XP towards the next one.
struct FarmLevelPill: View {
    let level: FarmLevel

    var body: some View {
        HStack(spacing: 8) {
            LevelBadge(level: level.level, size: 46)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#e6e2d8"))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#7ddc5f"), Color(hex: "#2bb673")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: min(geometry.size.width, max(14, geometry.size.width * level.progress)))
                        .opacity(level.xpInLevel > 0 ? 1 : 0)
                }
            }
            .frame(height: 14)
            .animation(.spring(response: 0.7, dampingFraction: 0.6), value: level)
        }
        .padding(.leading, 4)
        .padding(.trailing, 14)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(.white.opacity(0.94)).shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("garden.levelLabel \(level.level)"))
        .accessibilityIdentifier("farm-level")
    }
}

struct LevelBadge: View {
    let level: Int
    let size: CGFloat

    var body: some View {
        Text(verbatim: "\(level)")
            .font(.system(size: size * 0.48, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: "#5a3a00"))
            .frame(width: size, height: size)
            .background(
                RadialGradient(colors: [Color(hex: "#ffe680"), Color(hex: "#f5a623")], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7),
                in: .circle
            )
            .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 2).offset(y: 1).clipShape(Circle()))
    }
}

/// ⏱ 12:34 — gets warm and nudges in the last two minutes.
struct GardenClockPill: View {
    let clock: GardenClock
    let compact: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = clock.secondsLeft(now: context.date) ?? 0
            let minutes = (left + 59) / 60
            Text(verbatim: "\(compact ? "" : "⏱ ")\(left / 60):\(String(format: "%02d", left % 60))")
                .monospacedDigit()
                .farmPill(compact: compact, fill: left <= 120 ? Color(hex: "#ffe1a6") : .white.opacity(0.94))
                .accessibilityElement()
                .accessibilityLabel(Text("garden.timeLeft \(minutes)"))
                .accessibilityIdentifier("garden-clock")
        }
    }
}

/// A round white button with a symbol (zoom, close).
struct RoundTool: View {
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(FarmColors.ink.opacity(isEnabled ? 1 : 0.35))
                .frame(width: 48, height: 48)
                .background {
                    Circle().fill(.white.opacity(0.94)).shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(label))
    }
}

// MARK: Bottom bar

struct FarmBarButton: View {
    enum Style { case plain, shop, collect, active }

    let icon: String
    let title: LocalizedStringKey
    var style: Style = .plain
    var badge = 0
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(icon: String, title: LocalizedStringKey, style: Style = .plain, badge: Int = 0, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.style = style
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: icon).font(.system(size: 26))
                Text(title)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(style == .active ? .white : FarmColors.ink)
            .frame(minWidth: 66)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(background, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text(verbatim: "\(badge)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Color(hex: "#e2455b"), in: .capsule)
                        .overlay(Capsule().stroke(.white, lineWidth: 2))
                        .offset(x: 4, y: -4)
                }
            }
            .modifier(Nudge(active: style == .collect && !reduceMotion))
        }
        .buttonStyle(PressableStyle())
    }

    private var background: AnyShapeStyle {
        switch style {
        case .plain: AnyShapeStyle(Color(hex: "#f4efe4"))
        case .shop: AnyShapeStyle(LinearGradient(colors: [Color(hex: "#ffd25e"), Color(hex: "#f5a623")], startPoint: .top, endPoint: .bottom))
        case .collect: AnyShapeStyle(LinearGradient(colors: [Color(hex: "#a6e98a"), Color(hex: "#5cc24a")], startPoint: .top, endPoint: .bottom))
        case .active: AnyShapeStyle(FarmColors.ink)
        }
    }
}

/// A little hop now and then: "there's something to collect!"
private struct Nudge: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.keyframeAnimator(initialValue: CGFloat(0), repeating: true) { view, y in
                view.offset(y: y)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 1.45)
                    CubicKeyframe(-4, duration: 0.15)
                    CubicKeyframe(0, duration: 0.2)
                }
            }
        } else {
            content
        }
    }
}

// MARK: Drawers

/// The shop and the order board slide up from the bottom.
struct FarmDrawer<Content: View>: View {
    let title: LocalizedStringKey
    let maxHeight: CGFloat
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.funkelHeadline)
                        .foregroundStyle(FarmColors.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    RoundTool(symbol: "xmark", label: "garden.close", action: onClose)
                        .accessibilityIdentifier("sheet-close")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                ScrollView {
                    content()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: 760)
            .frame(maxHeight: maxHeight, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                FarmColors.sheet
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: -10)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct DrawerHeading: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key)
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .foregroundStyle(FarmColors.ink)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ShopCardLabel<Picture: View>: View {
    @ViewBuilder let picture: () -> Picture
    let name: LocalizedStringKey
    var price: String?
    var free = false
    var lock: String?
    var note: String?

    var body: some View {
        VStack(spacing: 5) {
            picture()
                .frame(width: 64, height: 64)
                .background(RadialGradient(colors: [Color(hex: "#e9f7df"), Color(hex: "#d3eec4")], center: UnitPoint(x: 0.5, y: 0.6), startRadius: 0, endRadius: 46), in: .rect(cornerRadius: 18, style: .continuous))
            Text(name)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let lock {
                Text(verbatim: "🔒 \(lock)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(FarmColors.muted)
            } else if let price {
                Text(verbatim: price)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(hex: free ? "#d7f5cf" : "#fff1c7"), in: .capsule)
            }
            if let note {
                Text(verbatim: note)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(FarmColors.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(FarmColors.ink)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}

struct ShopCardStyle: ButtonStyle {
    var locked = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .shadow(color: FarmColors.cardEdge, radius: 0, y: pressed ? 1 : 4)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
            }
            .offset(y: pressed ? 3 : 0)
            .opacity(isEnabled || locked ? 1 : 0.55)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

struct OrderCard: View {
    let order: FarmOrder
    let farm: Farm
    let onDeliver: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { wants; reward; Spacer(minLength: 0); action }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) { wants; reward }
                HStack { Spacer(); action }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white).shadow(color: FarmColors.cardEdge, radius: 0, y: 3)
        }
        .opacity(order.isDone ? 0.6 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("farm-order")
    }

    private var wants: some View {
        HStack(spacing: 12) {
            ForEach(Produce.allCases.filter { order.wants($0) > 0 }) { kind in
                Text(verbatim: "\(order.wants(kind)) \(kind.emoji)")
                    .foregroundStyle(order.isDone || farm.goods(kind) >= order.wants(kind) ? FarmColors.ink : Color(hex: "#b0a8b9"))
            }
        }
        .font(.system(size: 22, weight: .black, design: .rounded))
        .fixedSize()
    }

    private var reward: some View {
        Text(verbatim: "+\(order.stars) ⭐ · +\(order.xp) XP")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: "#6b5a00"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#fff1c7"), in: .capsule)
            .fixedSize()
    }

    @ViewBuilder private var action: some View {
        if order.isDone {
            Text(verbatim: "✓")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Palette.correct)
                .accessibilityLabel(Text("garden.delivered"))
        } else {
            let possible = farm.canFulfil(order)
            Button(action: onDeliver) {
                Text("garden.deliver")
                    .font(.system(.body, design: .rounded).weight(.black))
                    .foregroundStyle(possible ? .white : FarmColors.muted)
                    .shadow(color: .black.opacity(possible ? 0.2 : 0), radius: 0, y: 1)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        possible
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#a6e98a"), Color(hex: "#43b03a")], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color(hex: "#ddd6c8")),
                        in: .capsule
                    )
            }
            .buttonStyle(PressableStyle())
            .disabled(!possible)
            .fixedSize()
            .accessibilityIdentifier("order-deliver")
        }
    }
}

// MARK: Dialogs

/// "Feierabend auf dem Hof!": today's farm time is over.
struct SleepingFarm: View {
    let onBack: () -> Void
    let onMoreTime: () -> Void

    var body: some View {
        FarmDialog {
            Text(verbatim: "🌙")
                .font(.system(size: 64))
                .idleBob()
                .accessibilityHidden(true)
            Text("garden.timeUp")
                .font(.funkelTitle)
                .multilineTextAlignment(.center)
            Text("garden.timeUpText")
                .font(.funkelBody)
                .foregroundStyle(FarmColors.muted)
                .multilineTextAlignment(.center)
            BigButton(title: "play.back", color: FarmColors.ink, action: onBack)
                .accessibilityIdentifier("garden-time-back")
            Button(action: onMoreTime) {
                (Text(verbatim: "🔓 ") + Text("garden.moreTime"))
                    .font(.funkelCaption)
                    .foregroundStyle(FarmColors.muted)
                    .underline()
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("garden-more-time")
        }
        .accessibilityIdentifier("garden-time-up")
    }
}

/// "Hof-Level 4!" with what's new, and confetti.
struct LevelUpCard: View {
    let level: Int
    let onDone: () -> Void
    @State private var confetti = 0

    var body: some View {
        let unlocked = GardenItem.unlocked(at: level)
        ZStack {
            FarmDialog {
                LevelBadge(level: level, size: 96)
                    .shadow(color: Color(hex: "#f5a623").opacity(0.5), radius: 15, y: 10)
                    .background(Circle().fill(Color(hex: "#f5a623").opacity(0.25)).padding(-8))
                    .cheerfulHop(trigger: confetti)
                Text("garden.levelUp \(level)")
                    .font(.funkelTitle)
                if !unlocked.isEmpty {
                    Text("garden.unlocked")
                        .font(.funkelBody)
                        .foregroundStyle(FarmColors.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                        ForEach(unlocked) { item in
                            VStack(spacing: 4) {
                                Group {
                                    if item.connects {
                                        PathArt(id: item.id, links: Farm.Links(e: true, w: true)).frame(width: 56, height: 56)
                                    } else {
                                        GardenPicture(picture: item.shopPicture, size: 40).frame(width: 56, height: 56)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .background(Color(hex: "#d3eec4"), in: .rect(cornerRadius: 18, style: .continuous))
                                Text(LocalizedStringKey(item.nameKey))
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .multilineTextAlignment(.center)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                BigButton(title: "garden.great", color: FarmColors.ink, action: onDone)
                    .accessibilityIdentifier("level-up-ok")
            }
            ConfettiBurst(trigger: confetti, count: 60)
                .ignoresSafeArea()
        }
        .onAppear { confetti += 1 }
    }
}

/// A card in the middle of the farm, over a dimmed background.
struct FarmDialog<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    content()
                }
                .foregroundStyle(FarmColors.ink)
                .padding(28)
                .frame(maxWidth: 440)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 0)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// "🔓 Mehr Hofzeit": a grown-up gives extra minutes for today (behind the gate).
struct MoreGardenTime: View {
    let name: String
    let onCancel: () -> Void
    let onGrant: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text(verbatim: "⏱")
                        .font(.system(size: 56))
                        .accessibilityHidden(true)
                    Text("garden.moreTime")
                        .font(.funkelTitle)
                    Text("garden.moreTimeText \(name)")
                        .font(.funkelBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    ForEach(GardenTime.bonusChoices, id: \.self) { minutes in
                        BigButton(title: "garden.moreTime.minutes \(minutes)", color: Color(hex: "#34C77B")) { onGrant(minutes) }
                            .accessibilityIdentifier("garden-bonus-\(minutes)")
                    }
                    Text("garden.moreTime.footer")
                        .font(.funkelCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("editor.cancel", action: onCancel)
                }
            }
        }
    }
}
