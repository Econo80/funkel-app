import SwiftUI

// Drawn farm buildings, roads and textures (web/src/ui/play/FarmArt.tsx):
// there are no emoji for a barn or a chicken coop. Everything is drawn in the
// web app's SVG coordinates (a 100 × 100 box, the pond 200 × 100, the
// windmill 100 × 200) and scaled to fit.

/// An emoji, or a drawn building for "art:<id>".
struct GardenPicture: View {
    let picture: String
    var size: CGFloat

    var body: some View {
        if picture.hasPrefix("art:") {
            FarmArt(id: String(picture.dropFirst(4)))
        } else {
            Text(verbatim: picture)
                .font(.system(size: size))
                .fixedSize()
        }
    }
}

struct FarmArt: View {
    let id: String

    var body: some View {
        switch id {
        case "windmill":
            WindmillArt()
        case "road", "path", "fence":
            PathArt(id: id, links: Farm.Links())
        default:
            Canvas { context, size in
                let box = id == "pond" ? CGSize(width: 200, height: 100) : CGSize(width: 100, height: 100)
                var c = context
                ArtPen.fit(&c, size: size, box: box)
                ArtPen.draw(id, in: &c)
            }
            .aspectRatio(id == "pond" ? 2 : 1, contentMode: .fit)
        }
    }
}

/// The windmill's blades turn slowly (not with Reduce Motion).
private struct WindmillArt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { context, size in
                var c = context
                ArtPen.fit(&c, size: size, box: CGSize(width: 100, height: 200))
                ArtPen.windmillTower(&c)
            }
            Group {
                if reduceMotion {
                    blades
                } else {
                    blades.keyframeAnimator(initialValue: 0.0, repeating: true) { content, angle in
                        content.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: 0.36))
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(360.0, duration: 7)
                        }
                    }
                }
            }
        }
        .aspectRatio(0.5, contentMode: .fit)
    }

    private var blades: some View {
        Canvas { context, size in
            var c = context
            ArtPen.fit(&c, size: size, box: CGSize(width: 100, height: 200))
            ArtPen.windmillBlades(&c)
        }
    }
}

/// Roads, footpaths and fences drawn to join their neighbours: straight pieces,
/// corners, T-junctions and crossings all come from the same four "arms".
/// A piece on its own lies left to right.
struct PathArt: View {
    let id: String
    let links: Farm.Links

    var body: some View {
        Canvas { context, size in
            var c = context
            c.scaleBy(x: size.width / 100, y: size.height / 100)
            let l = links.any ? links : Farm.Links(e: true, w: true)
            if id == "fence" {
                ArtPen.fence(&c, links: l)
            } else {
                ArtPen.way(&c, road: id == "road", links: l)
            }
        }
    }
}

// MARK: Drawing

private enum ArtPen {
    static func fit(_ c: inout GraphicsContext, size: CGSize, box: CGSize) {
        let scale = min(size.width / box.width, size.height / box.height)
        c.translateBy(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)
        c.scaleBy(x: scale, y: scale)
    }

    static func poly(_ points: [CGPoint], closed: Bool = true) -> Path {
        Path { p in
            p.addLines(points)
            if closed { p.closeSubpath() }
        }
    }

    static func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
    }

    static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    static func color(_ hex: String) -> GraphicsContext.Shading { .color(Color(hex: hex)) }

    static func stroke(_ c: inout GraphicsContext, _ path: Path, _ hex: String, _ width: CGFloat, round: Bool = true) {
        c.stroke(path, with: color(hex), style: StrokeStyle(lineWidth: width, lineCap: round ? .round : .butt, lineJoin: .round))
    }

    /// A gable roof's thick edge.
    static func roof(_ c: inout GraphicsContext, _ a: CGPoint, _ top: CGPoint, _ b: CGPoint, _ hex: String) {
        stroke(&c, poly([a, top, b], closed: false), hex, 7)
    }

    static func draw(_ id: String, in c: inout GraphicsContext) {
        switch id {
        case "barn":
            c.fill(poly([pt(12, 46), pt(50, 14), pt(88, 46), pt(88, 94), pt(12, 94)]), with: color("#C8433A"))
            roof(&c, pt(6, 49), pt(50, 11), pt(94, 49), "#7A2A24")
            c.fill(rect(35, 58, 30, 36), with: color("#F4E9D8"))
            stroke(&c, line(38, 61, 62, 91), "#C8433A", 4, round: false)
            stroke(&c, line(62, 61, 38, 91), "#C8433A", 4, round: false)
            c.fill(rect(42, 30, 16, 14, r: 2), with: color("#F4E9D8"))
            stroke(&c, line(50, 30, 50, 44), "#C8433A", 3, round: false)
        case "farmhouse":
            c.fill(rect(66, 16, 10, 20), with: color("#8A5A3C"))
            c.fill(rect(16, 46, 68, 48), with: color("#F6E7C8"))
            c.fill(poly([pt(8, 50), pt(50, 14), pt(92, 50)]), with: color("#B5542F"))
            c.fill(rect(44, 66, 14, 28, r: 2), with: color("#8A5A3C"))
            for x in [24.0, 64.0] {
                c.fill(rect(x, 58, 13, 13), with: color("#7EC8F0"))
                c.stroke(rect(x, 58, 13, 13), with: .color(.white), lineWidth: 2)
            }
            stroke(&c, line(20, 94, 84, 94), "#5DAA4F", 5, round: false)
        case "coop":
            c.fill(poly([pt(18, 50), pt(50, 22), pt(82, 50), pt(82, 88), pt(18, 88)]), with: color("#D9A55B"))
            roof(&c, pt(12, 53), pt(50, 19), pt(88, 53), "#8A5A3C")
            stroke(&c, line(18, 62, 82, 62), "#B9843E", 2, round: false)
            stroke(&c, line(18, 75, 82, 75), "#B9843E", 2, round: false)
            c.fill(circle(50, 62, 10), with: color("#5A3A22"))
            stroke(&c, line(40, 88, 60, 72), "#8A5A3C", 5)
        case "doghouse":
            c.fill(poly([pt(20, 50), pt(50, 24), pt(80, 50), pt(80, 88), pt(20, 88)]), with: color("#4E8FD6"))
            roof(&c, pt(14, 53), pt(50, 21), pt(86, 53), "#2C5E99")
            let door = Path { p in
                p.move(to: pt(38, 88))
                p.addLine(to: pt(38, 68))
                p.addArc(center: pt(50, 68), radius: 12, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                p.addLine(to: pt(62, 88))
                p.closeSubpath()
            }
            c.fill(door, with: color("#23324A"))
            c.fill(rect(40, 38, 20, 8, r: 3), with: color("#FFF3D6"))
        case "pond":
            c.fill(ellipse(100, 56, 92, 38), with: color("#8AD0F5"))
            c.fill(ellipse(100, 58, 80, 30), with: color("#4FAEE8"))
            let ripples = Path { p in
                p.move(to: pt(60, 52))
                p.addQuadCurve(to: pt(90, 52), control: pt(75, 46))
                p.move(to: pt(110, 66))
                p.addQuadCurve(to: pt(140, 66), control: pt(125, 60))
            }
            stroke(&c, ripples, "#BDE6FA", 4)
            for (x, y1, y2) in [(22.0, 50.0, 26.0), (30, 52, 20), (178, 52, 24)] {
                stroke(&c, line(x, y1, x, y2), "#4E9A3C", 5)
            }
            c.fill(ellipse(30, 22, 4, 9), with: color("#8A5A3C"))
            c.fill(ellipse(178, 24, 4, 9), with: color("#8A5A3C"))
        case "beehive":
            c.fill(rect(44, 78, 12, 16), with: color("#8A5A3C"))
            let hive = Path { p in
                p.move(to: pt(22, 80))
                p.addQuadCurve(to: pt(50, 22), control: pt(20, 40))
                p.addQuadCurve(to: pt(78, 80), control: pt(80, 40))
                p.closeSubpath()
            }
            c.fill(hive, with: color("#F2B640"))
            for y in [36.0, 48, 60, 72] {
                let band = Path { p in
                    p.move(to: pt(24 + (80 - y) * 0.1, y))
                    p.addQuadCurve(to: pt(76 - (80 - y) * 0.1, y), control: pt(50, y + 6))
                }
                stroke(&c, band, "#C98A1E", 3, round: false)
            }
            let door = Path { p in
                p.move(to: pt(42, 80))
                p.addArc(center: pt(50, 80), radius: 8, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                p.closeSubpath()
            }
            c.fill(door, with: color("#5A3A22"))
            c.fill(circle(76, 30, 4), with: color("#FFD43B"))
            stroke(&c, line(72, 27, 68, 23), "#5A3A22", 2, round: false)
            stroke(&c, line(80, 27, 84, 23), "#5A3A22", 2, round: false)
        default:
            break
        }
    }

    static func windmillTower(_ c: inout GraphicsContext) {
        let tower = poly([pt(34, 196), pt(42, 80), pt(58, 80), pt(66, 196)])
        c.fill(tower, with: color("#F3E3C3"))
        c.stroke(tower, with: color("#C9AE80"), lineWidth: 2)
        c.fill(poly([pt(38, 84), pt(50, 64), pt(62, 84)]), with: color("#B5542F"))
        c.fill(rect(44, 160, 12, 36, r: 6), with: color("#8A5A3C"))
        c.fill(rect(45, 110, 10, 12), with: color("#7EC8F0"))
        c.stroke(rect(45, 110, 10, 12), with: .color(.white), lineWidth: 2)
    }

    static func windmillBlades(_ c: inout GraphicsContext) {
        for angle in [0.0, 90, 180, 270] {
            var blade = c
            blade.translateBy(x: 50, y: 72)
            blade.rotate(by: .degrees(angle))
            blade.translateBy(x: -50, y: -72)
            blade.fill(rect(47, 22, 6, 50), with: color("#8A5A3C"))
            blade.fill(rect(53, 24, 14, 40), with: color("#FFF8EA"))
            blade.stroke(rect(53, 24, 14, 40), with: color("#C9AE80"), lineWidth: 2)
        }
        c.fill(circle(50, 72, 6), with: color("#5A3A22"))
    }

    static func fence(_ c: inout GraphicsContext, links l: Farm.Links) {
        for y in [40.0, 62.0] {
            let x = 50 - (y - 50)
            let rails = Path { p in
                p.move(to: pt(l.w ? 0 : 50, y))
                p.addLine(to: pt(l.e ? 100 : 50, y))
                p.move(to: pt(x, l.n ? 0 : 50))
                p.addLine(to: pt(x, l.s ? 100 : 50))
            }
            c.stroke(rails, with: color("#B07A4A"), style: StrokeStyle(lineWidth: 7, lineCap: .square))
        }
        c.fill(poly([pt(43, 80), pt(43, 30), pt(50, 22), pt(57, 30), pt(57, 80)]), with: color("#8A5A3C"))
    }

    static func way(_ c: inout GraphicsContext, road: Bool, links l: Farm.Links) {
        let (a, b): (CGFloat, CGFloat) = road ? (20, 80) : (32, 68)
        var shape = Path(CGRect(x: a, y: a, width: b - a, height: b - a))
        if l.n { shape.addRect(CGRect(x: a, y: 0, width: b - a, height: 50)) }
        if l.s { shape.addRect(CGRect(x: a, y: 50, width: b - a, height: 50)) }
        if l.w { shape.addRect(CGRect(x: 0, y: a, width: 50, height: b - a)) }
        if l.e { shape.addRect(CGRect(x: 50, y: a, width: 50, height: b - a)) }
        c.fill(shape, with: color(road ? "#6E737B" : "#E6CC9C"))
        if road {
            let dashes = Path { p in
                if l.n { p.move(to: pt(50, 4)); p.addLine(to: pt(50, 36)) }
                if l.s { p.move(to: pt(50, 64)); p.addLine(to: pt(50, 96)) }
                if l.w { p.move(to: pt(4, 50)); p.addLine(to: pt(36, 50)) }
                if l.e { p.move(to: pt(64, 50)); p.addLine(to: pt(96, 50)) }
            }
            c.stroke(dashes, with: color("#F4F1E8"), style: StrokeStyle(lineWidth: 4, dash: [10, 8]))
        } else {
            for (x, y, r) in [(42.0, 44.0, 3.0), (58, 57, 2.5), (47, 60, 2)] {
                c.fill(circle(x, y, r), with: color("#C9A86E"))
            }
        }
    }
}

// MARK: Textures

/// Small tiles drawn once and repeated: the forest around the farm, the grass,
/// tilled soil and the striped ground of a building site.
@MainActor
enum FarmTextures {
    static let forest = tile(CGSize(width: 64, height: 64)) { c in
        c.fill(ArtPen.poly([ArtPen.pt(16, 4), ArtPen.pt(28, 30), ArtPen.pt(4, 30)]), with: ArtPen.color("#2f7a3a"))
        c.fill(ArtPen.rect(14, 30, 4, 6), with: ArtPen.color("#6b4423"))
        c.fill(ArtPen.poly([ArtPen.pt(48, 34), ArtPen.pt(60, 60), ArtPen.pt(36, 60)]), with: ArtPen.color("#367f40"))
        c.fill(ArtPen.rect(46, 60, 4, 4), with: ArtPen.color("#6b4423"))
    }

    static let grass = tile(CGSize(width: 96, height: 96)) { c in
        for (x, y, dx, h1, h2) in [(12.0, 20.0, 3.0, 7.0, 8.0), (60, 44, 3, 7, 8), (30, 78, 3, 6, 7), (84, 86, 2, 6, 7)] {
            let tuft = Path { p in
                p.move(to: ArtPen.pt(x, y)); p.addLine(to: ArtPen.pt(x - dx, y - h1))
                p.move(to: ArtPen.pt(x, y)); p.addLine(to: ArtPen.pt(x, y - h2))
                p.move(to: ArtPen.pt(x, y)); p.addLine(to: ArtPen.pt(x + dx, y - h1))
            }
            ArtPen.stroke(&c, tuft, "#5fae48", 2)
        }
        c.fill(ArtPen.circle(76, 16, 2.5), with: ArtPen.color("#fff8d6"))
        c.fill(ArtPen.circle(40, 54, 2), with: ArtPen.color("#ffd43b"))
        c.fill(ArtPen.circle(8, 62, 2), with: ArtPen.color("#fff8d6"))
    }

    static let soil = tile(CGSize(width: 10, height: 10)) { c in
        c.fill(ArtPen.rect(0, 0, 10, 7), with: ArtPen.color("#8b5a2b"))
        c.fill(ArtPen.rect(0, 7, 10, 3), with: ArtPen.color("#74471f"))
    }

    static let site = tile(CGSize(width: 28.28, height: 28.28)) { c in
        c.fill(ArtPen.rect(0, 0, 28.28, 28.28), with: ArtPen.color("#c9a36a"))
        let stripes = Path { p in
            for k in stride(from: -28.28, through: 28.28, by: 28.28) {
                p.move(to: ArtPen.pt(k, 28.28))
                p.addLine(to: ArtPen.pt(k + 28.28, 0))
            }
        }
        c.stroke(stripes, with: ArtPen.color("#d9b47a"), lineWidth: 10)
    }

    private static func tile(_ size: CGSize, draw: @escaping (inout GraphicsContext) -> Void) -> Image {
        let renderer = ImageRenderer(content: Canvas { context, _ in
            var c = context
            draw(&c)
        }.frame(width: size.width, height: size.height))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return Image(systemName: "square") }
        return Image(uiImage: image)
    }
}
