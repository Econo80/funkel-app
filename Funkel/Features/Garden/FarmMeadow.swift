import SwiftUI

/// Sizes of the farm on screen: one square, the meadow around the grid, and the
/// forest around the meadow (room for the HUD on top and the bar below).
struct FarmLayout: Equatable {
    /// Zoom steps: the size of one square in points.
    static let cellSizes: [CGFloat] = [44, 60, 80]

    let cell: CGFloat
    let rows: Int
    let compact: Bool

    let pad: CGFloat = 24
    var top: CGFloat { compact ? 84 : 96 }
    var side: CGFloat { compact ? 32 : 64 }
    var bottom: CGFloat { compact ? 140 : 150 }

    var gridSize: CGSize { CGSize(width: CGFloat(Farm.columns) * cell, height: CGFloat(rows) * cell) }
    var meadowSize: CGSize { CGSize(width: gridSize.width + 2 * pad, height: gridSize.height + 2 * pad) }
    var contentSize: CGSize { CGSize(width: meadowSize.width + 2 * side, height: meadowSize.height + top + bottom) }

    /// Top-left corner of a square in the grid's coordinates.
    func origin(of index: Int) -> CGPoint {
        CGPoint(x: CGFloat(index % Farm.columns) * cell, y: CGFloat(index / Farm.columns) * cell)
    }

    /// The square under a point in the grid's coordinates.
    func cell(at point: CGPoint) -> Int? {
        let col = Int((point.x / cell).rounded(.down)), row = Int((point.y / cell).rounded(.down))
        guard (0..<Farm.columns).contains(col), (0..<rows).contains(row) else { return nil }
        return row * Farm.columns + col
    }
}

/// A "+1 🥚" or "+3 XP" that floats up from a square.
struct FarmPopup: Identifiable, Equatable {
    enum Kind { case goods, xp, sparkle }
    let id: Int
    let cell: Int
    let text: String
    let kind: Kind
}

/// The ground with everything on it. Taps and finger-drawing are reported as squares.
struct FarmMeadow: View {
    let farm: Farm
    let now: Date
    let layout: FarmLayout
    var showsFreeSquares = false
    var movingAnchor: Int?
    var popups: [FarmPopup] = []
    var onTap: (Int) -> Void = { _ in }
    /// Set while a road, path or fence is chosen: a finger drawing across squares.
    var onDraw: ((Int) -> Void)?
    var onDrawEnd: () -> Void = {}

    var body: some View {
        let covered = Farm.occupancy(farm.garden)
        ZStack(alignment: .topLeading) {
            Color(hex: "#3d8a43")
            FarmTextures.forest.resizable(resizingMode: .tile)
            meadow
                .offset(x: layout.side, y: layout.top)
            grid(covered: covered)
                .frame(width: layout.gridSize.width, height: layout.gridSize.height, alignment: .topLeading)
                .offset(x: layout.side + layout.pad, y: layout.top + layout.pad)
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
    }

    private var meadow: some View {
        let shape = RoundedRectangle(cornerRadius: 36, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [Color(hex: "#8fd970"), Color(hex: "#73c457")], startPoint: .top, endPoint: .bottom))
            shape.fill(RadialGradient(colors: [Color(hex: "#a3e283"), Color(hex: "#a3e283").opacity(0)], center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: max(layout.meadowSize.width, layout.meadowSize.height) * 0.6))
            FarmTextures.grass.resizable(resizingMode: .tile).clipShape(shape)
        }
        .frame(width: layout.meadowSize.width, height: layout.meadowSize.height)
        .background {
            shape.inset(by: -7).stroke(Color.black.opacity(0.12), lineWidth: 6).padding(-3)
        }
        .background {
            shape.inset(by: -4).stroke(Color(hex: "#6cb653"), lineWidth: 8)
        }
        .shadow(color: .black.opacity(0.3), radius: 30, y: 24)
    }

    private func grid(covered: [Int?]) -> some View {
        let anchors = farm.garden.indices.filter { farm.garden[$0] != nil }
        let ways = anchors.filter { farm.garden[$0]?.item?.connects == true }
        let objects = anchors
            .filter { anchor in farm.garden[anchor]?.item.map { item in !item.connects } ?? false }
            .sorted { bottomRow($0) == bottomRow($1) ? $0 < $1 : bottomRow($0) < bottomRow($1) }
        return ZStack(alignment: .topLeading) {
            if showsFreeSquares {
                FreeSquares(covered: covered, layout: layout)
            }
            ForEach(ways, id: \.self) { anchor in
                let plot = farm.garden[anchor]!
                PathArt(id: plot.itemId, links: Farm.connections(farm.garden, cell: anchor))
                    .frame(width: layout.cell, height: layout.cell)
                    .offset(x: layout.origin(of: anchor).x, y: layout.origin(of: anchor).y)
                    .accessibilityElement()
                    .accessibilityLabel(Text(LocalizedStringKey(plot.item?.nameKey ?? "garden.empty")))
            }
            ForEach(objects, id: \.self) { anchor in
                let plot = farm.garden[anchor]!
                let item = plot.item!
                FarmObject(
                    item: item,
                    picture: Farm.picture(of: plot, now: now),
                    cell: layout.cell,
                    ready: Farm.readyProduce(plot, now: now),
                    building: Farm.isUnderConstruction(plot, now: now),
                    moving: movingAnchor == anchor,
                    seed: anchor
                )
                .frame(width: CGFloat(item.width) * layout.cell, height: CGFloat(item.height) * layout.cell, alignment: .bottom)
                .id("\(anchor)-\(plot.itemId)")
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .offset(x: layout.origin(of: anchor).x, y: layout.origin(of: anchor).y)
                .accessibilityElement()
                .accessibilityLabel(Text(LocalizedStringKey(item.nameKey)))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTap(anchor) }
            }
            ForEach(popups) { popup in
                PopupLabel(popup: popup)
                    .position(x: layout.origin(of: popup.cell).x + layout.cell / 2, y: layout.origin(of: popup.cell).y)
            }
        }
        .frame(width: layout.gridSize.width, height: layout.gridSize.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { value in
            if let cell = layout.cell(at: value.location) { onTap(cell) }
        }, including: onDraw == nil ? .all : .subviews)
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            if let cell = layout.cell(at: value.location) { onDraw?(cell) }
        }.onEnded { _ in onDrawEnd() }, including: onDraw == nil ? .subviews : .all)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("garden-ground")
    }

    private func bottomRow(_ anchor: Int) -> Int {
        anchor / Farm.columns + (farm.garden[anchor]?.item?.height ?? 1)
    }
}

/// While placing: a soft outline on every free square.
private struct FreeSquares: View {
    let covered: [Int?]
    let layout: FarmLayout

    var body: some View {
        Canvas { context, _ in
            for (index, owner) in covered.enumerated() where owner == nil {
                let origin = layout.origin(of: index)
                let rect = CGRect(x: origin.x + 1, y: origin.y + 1, width: layout.cell - 2, height: layout.cell - 2)
                context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(.white.opacity(0.55)), lineWidth: 1.5)
            }
        }
        .frame(width: layout.gridSize.width, height: layout.gridSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: Objects

/// One thing on the farm, standing on the meadow with a soft shadow. Crops and
/// trees sway, animals wander and turn, buildings are taller than their squares.
private struct FarmObject: View {
    let item: GardenItem
    let picture: String
    let cell: CGFloat
    let ready: Produce?
    let building: Bool
    let moving: Bool
    let seed: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Kind { case crop, plant, animal, art, plain }

    private var kind: Kind {
        if item.category == .animals { return .animal }
        if item.harvest != nil || item.id == "flower" { return .crop }
        if item.category == .plants { return .plant }
        return picture.hasPrefix("art:") ? .art : .plain
    }

    private var width: CGFloat { CGFloat(item.width) * cell }
    private var height: CGFloat { CGFloat(item.height) * cell }
    /// A little different for every square, so not everything moves in step.
    private var jitter: Double { Double((seed * 37) % 23) / 23 }

    var body: some View {
        ZStack(alignment: .bottom) {
            if kind == .crop {
                RoundedRectangle(cornerRadius: width * 0.86 * 0.22, style: .continuous)
                    .fill(ImagePaint(image: FarmTextures.soil))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: width * 0.2).fill(.white.opacity(0.15)).frame(height: 2).padding(.horizontal, width * 0.1)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 0, y: 3)
                    .padding(width * 0.07)
                    .frame(width: width, height: height)
            }
            if building {
                RoundedRectangle(cornerRadius: width * 0.88 * 0.16, style: .continuous)
                    .fill(ImagePaint(image: FarmTextures.site))
                    .opacity(0.8)
                    .padding(width * 0.06)
                    .frame(width: width, height: height)
            }
            if kind != .crop {
                shadow
            }
            animated(pictureView)
            if kind == .crop, ready != nil {
                ReadyGlow(width: width)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
        .overlay(alignment: .topTrailing) {
            if building {
                Hammer(size: cell * 0.34)
                    .padding(.top, height * 0.06)
                    .padding(.trailing, width * 0.08)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let ready {
                Bubble(produce: ready, cell: cell)
                    .offset(x: width * 0.08, y: -height * 0.12)
            }
        }
        .overlay {
            if moving {
                MovingFrame()
            }
        }
        .allowsHitTesting(false)
    }

    private var shadow: some View {
        let inset: CGFloat = kind == .art ? 0.06 : (item.id == "tree" || item.id == "appletree" ? 0.12 : 0.2)
        return Ellipse()
            .fill(Color(red: 20 / 255, green: 60 / 255, blue: 10 / 255).opacity(0.28))
            .frame(width: width * (1 - 2 * inset), height: height * (kind == .art ? 0.18 : 0.16))
            .blur(radius: 1.5)
            .padding(.bottom, height * (kind == .art ? 0.03 : 0.07))
    }

    private var emojiSize: CGFloat {
        if item.id == "tree" || item.id == "appletree" { return cell }
        return cell * (kind == .animal ? 0.72 : 0.64)
    }

    @ViewBuilder private var pictureView: some View {
        if kind == .art {
            GardenPicture(picture: picture, size: emojiSize)
                .frame(width: width, height: height * 1.18, alignment: .bottom)
                .padding(.bottom, height * 0.04)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 2)
        } else {
            GardenPicture(picture: picture, size: emojiSize)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 2)
                .padding(.bottom, height * 0.1)
        }
    }

    @ViewBuilder private func animated(_ content: some View) -> some View {
        if reduceMotion || building {
            content
        } else {
            switch kind {
            case .crop, .plant:
                content.phaseAnimator([false, true]) { view, right in
                    view.rotationEffect(.degrees(right ? 3 : -3), anchor: .bottom)
                } animation: { _ in .easeInOut(duration: 1.6 + jitter * 0.4) }
            case .animal:
                content
                    .phaseAnimator([false, true]) { view, up in
                        view.offset(y: up ? -emojiSize * 0.06 : 0)
                    } animation: { _ in .easeInOut(duration: 0.42 + jitter * 0.1) }
                    .keyframeAnimator(initialValue: Wander(), repeating: true) { view, wander in
                        view.scaleEffect(x: wander.facing, y: 1).offset(x: wander.x * width)
                    } keyframes: { _ in
                        let walk = 3.4 + jitter * 0.8
                        KeyframeTrack(\.x) {
                            CubicKeyframe(0.12, duration: walk)
                            LinearKeyframe(0.12, duration: 0.4)
                            CubicKeyframe(-0.12, duration: walk)
                            LinearKeyframe(-0.12, duration: 0.4)
                        }
                        KeyframeTrack(\.facing) {
                            LinearKeyframe(-1, duration: walk)
                            LinearKeyframe(1, duration: 0.4)
                            LinearKeyframe(1, duration: walk)
                            LinearKeyframe(-1, duration: 0.4)
                        }
                    }
            default:
                content
            }
        }
    }

    private struct Wander {
        var x: CGFloat = -0.12
        var facing: CGFloat = -1
    }
}

/// Something to collect: a bubble with what it is.
private struct Bubble: View {
    let produce: Produce
    let cell: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bubble = Text(verbatim: produce.emoji)
            .font(.system(size: cell * 0.3))
            .frame(width: cell * 0.52, height: cell * 0.52)
            .background(.white, in: .circle)
            .shadow(color: .black.opacity(0.22), radius: 4, y: 3)
        if reduceMotion {
            bubble
        } else {
            bubble.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -5 : 0)
            } animation: { _ in .easeInOut(duration: 0.7) }
        }
    }
}

private struct Hammer: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hammer = Text(verbatim: "🔨").font(.system(size: size))
        if reduceMotion {
            hammer
        } else {
            hammer.phaseAnimator([false, true]) { view, down in
                view.rotationEffect(.degrees(down ? 20 : -30), anchor: UnitPoint(x: 0.8, y: 0.8))
            } animation: { _ in .easeInOut(duration: 0.5) }
        }
    }
}

/// Ready crops glow.
private struct ReadyGlow: View {
    let width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let glow = RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
            .stroke(Color(red: 1, green: 236 / 255, blue: 120 / 255).opacity(0.9), lineWidth: 3)
            .shadow(color: Color(red: 1, green: 220 / 255, blue: 80 / 255).opacity(0.85), radius: 9)
            .padding(width * 0.04)
        if reduceMotion {
            glow
        } else {
            glow.phaseAnimator([false, true]) { view, bright in
                view.opacity(bright ? 1 : 0.55)
            } animation: { _ in .easeInOut(duration: 0.8) }
        }
    }
}

private struct MovingFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
            .phaseAnimator([false, true]) { view, right in
                view.rotationEffect(.degrees(right ? 2 : -2))
            } animation: { _ in .easeInOut(duration: 0.35) }
    }
}

private struct PopupLabel: View {
    let popup: FarmPopup
    @State private var trigger = false

    var body: some View {
        Text(verbatim: popup.text)
            .font(.system(size: popup.kind == .sparkle ? 32 : popup.kind == .xp ? 16 : 20, weight: .black, design: .rounded))
            .foregroundStyle(popup.kind == .xp ? Color(hex: "#ffe066") : .white)
            .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
            .shadow(color: .black.opacity(0.25), radius: 4)
            .fixedSize()
            .keyframeAnimator(initialValue: Rise(), trigger: trigger) { view, value in
                view
                    .opacity(value.opacity)
                    .scaleEffect(value.scale)
                    .offset(y: value.y)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.2)
                    LinearKeyframe(1, duration: 0.6)
                    LinearKeyframe(0, duration: 0.5)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.15, duration: 0.2)
                    CubicKeyframe(1, duration: 1.1)
                }
                KeyframeTrack(\.y) {
                    LinearKeyframe(0, duration: 0.2)
                    CubicKeyframe(-64, duration: 1.1)
                }
            }
            .onAppear { trigger.toggle() }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    struct Rise {
        var opacity = 0.0
        var scale: CGFloat = 0.6
        var y: CGFloat = 10
    }
}
