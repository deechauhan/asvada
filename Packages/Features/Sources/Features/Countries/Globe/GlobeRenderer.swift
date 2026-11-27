import DesignSystem
import Geo
import simd
import SwiftUI

/// Where the globe sits in its frame, and where the flat map would: the unroll morph runs
/// between the two.
struct GlobeLayout {
    /// The globe's frame, width over height: taller than the flat map, so the ball has room.
    static let globeAspect: CGFloat = 1.15
    /// Room between the ball and the frame's edge.
    static let inset: CGFloat = 10

    let size: CGSize

    /// The frame's aspect `unroll` of the way from the globe to the flat map.
    static func aspect(unroll: Double, flat: CGFloat = InkWorld.shared.aspectRatio) -> CGFloat {
        globeAspect + (flat - globeAspect) * min(max(unroll, 0), 1)
    }

    var centre: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    var radius: Double {
        max(min(size.width, size.height) / 2 - Self.inset, 1)
    }

    /// Where the flat map lands when the globe has unrolled: full width, centred.
    var mapRect: CGRect {
        let height = size.width / InkWorld.shared.aspectRatio
        return CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
    }

    func projection(_ camera: GlobeCamera) -> GlobeProjection {
        GlobeProjection(camera: camera, centre: centre, radius: radius)
    }
}

/// Draws the ink globe into a Canvas: countries as paper cut-outs on a paper sea, the ones
/// you've been to in plum ink, clipped at the horizon. While it moves it draws the coarse outlines.
struct GlobeRenderer {
    let world: InkGlobeWorld
    let projection: GlobeProjection
    let moving: Bool
    private let farSide: GeoPoint

    init(world: InkGlobeWorld = .shared, projection: GlobeProjection, moving: Bool) {
        self.world = world
        self.projection = projection
        self.moving = moving
        farSide = projection.farSide
    }

    var disc: CGRect {
        CGRect(
            x: projection.centre.x - projection.radius,
            y: projection.centre.y - projection.radius,
            width: projection.radius * 2,
            height: projection.radius * 2,
        )
    }

    // MARK: - Outlines

    /// One ring on screen, clipped at the horizon: the part round the back is pushed out to the
    /// rim, so its fill follows the edge of the ball. Nil when it's wholly round the back. A ring
    /// that holds the far side gets the rim added, so an even-odd fill turns it inside out.
    func outline(_ ring: GlobeRing) -> Path? {
        let middle = projection.view(ring.middle)
        guard middle.z >= -ring.reach else { return nil }
        let points = moving ? ring.coarse : ring.points
        guard let last = points.last else { return nil }
        var path = Path()
        if middle.z > ring.reach {
            path.addLines(points.map { projection.screen(projection.view($0)) })
            path.closeSubpath()
            return path
        }
        var screen: [CGPoint] = []
        screen.reserveCapacity(points.count + 4)
        var seen = false
        var previous = projection.view(last)
        for point in points {
            let here = projection.view(point)
            if (previous.z > 0) != (here.z > 0) {
                // Where the edge goes over the horizon.
                let crossing = previous + (here - previous) * (previous.z / (previous.z - here.z))
                screen.append(projection.limb(crossing))
            }
            if here.z > 0 {
                seen = true
                screen.append(projection.screen(here))
            } else {
                screen.append(projection.limb(here))
            }
            previous = here
        }
        guard seen else { return nil }
        path.addLines(screen)
        path.closeSubpath()
        if ring.contains(farSide) {
            path.addEllipse(in: disc)
        }
        return path
    }

    /// A country's visible outline, or nil when none of it faces you.
    func outline(_ country: GlobeCountry) -> Path? {
        var path = Path()
        var any = false
        for ring in country.rings {
            if let outline = outline(ring) {
                path.addPath(outline)
                any = true
            }
        }
        return any ? path : nil
    }

    // MARK: - Drawing

    func draw(in context: GraphicsContext, visited: Set<String>) {
        let ball = Path(ellipseIn: disc)
        context.fill(ball, with: .color(Palette.surface.color))
        let paper = Palette.separator.color
        let edge = Palette.background.color
        let fill = FillStyle(eoFill: true)
        for ring in world.land {
            if let path = outline(ring) {
                context.fill(path, with: .color(paper), style: fill)
            }
        }
        for country in world.countries {
            guard let path = outline(country) else { continue }
            context.fill(path, with: .color(visited.contains(country.code) ? Palette.brand.color : paper), style: fill)
            context.stroke(path, with: .color(edge), lineWidth: 0.5)
        }
        // A little shade towards the rim, so it reads as a ball rather than a disc.
        context.fill(ball, with: .radialGradient(
            Gradient(colors: [.clear, Palette.textPrimary.color.opacity(0.1)]),
            center: projection.centre,
            startRadius: projection.radius * 0.55,
            endRadius: projection.radius,
        ))
        context.stroke(ball, with: .color(Palette.brand.color.opacity(0.35)), lineWidth: 1)
    }

    /// A stamp landing on `code`: the rubber's ring thunks down (1.4× to 1) on the country's
    /// middle, then ink floods out from it while a fainter ring spreads and fades. A plain fade
    /// under Reduce Motion.
    func drawBloom(in context: GraphicsContext, code: String, progress: Double, reduceMotion: Bool) {
        guard let country = world.country(code: code), let path = outline(country) else { return }
        let ink = Palette.brand.color
        let fill = FillStyle(eoFill: true)
        if reduceMotion {
            var faded = context
            faded.opacity = progress
            faded.fill(path, with: .color(ink), style: fill)
            return
        }
        let origin = projection.screen(of: country.anchor.point) ?? projection.centre
        let box = path.boundingRect
        let reach = [
            CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY),
        ]
        .map { hypot($0.x - origin.x, $0.y - origin.y) }
        .max() ?? 0
        let flood = reach * min(progress / 0.55, 1)
        var flooded = context
        flooded.clip(to: Path(ellipseIn: CGRect(x: origin.x - flood, y: origin.y - flood, width: flood * 2, height: flood * 2)))
        flooded.fill(path, with: .color(ink), style: fill)
        let spread = max(reach, 20) * 1.5 * progress
        context.stroke(
            Path(ellipseIn: CGRect(x: origin.x - spread, y: origin.y - spread, width: spread * 2, height: spread * 2)),
            with: .color(ink.opacity(0.5 * (1 - progress))),
            lineWidth: 2,
        )
        let rubber = 15 * (1 + 0.4 * (1 - min(progress / 0.2, 1)))
        context.stroke(
            Path(ellipseIn: CGRect(x: origin.x - rubber, y: origin.y - rubber, width: rubber * 2, height: rubber * 2)),
            with: .color(ink.opacity(1 - progress)),
            lineWidth: 2.5,
        )
    }

    /// The unroll morph, `progress` of the way from the globe to the flat map in `mapRect`: every
    /// point slides from where the globe shows it to where the flat map does, and the countries
    /// round the back fade in as they come round.
    func drawUnrolling(in context: GraphicsContext, mapRect: CGRect, progress: Double, visited: Set<String>) {
        let paper = Palette.separator.color
        let edge = Palette.background.color
        var ball = context
        ball.opacity = 1 - progress
        ball.fill(Path(ellipseIn: disc), with: .color(Palette.surface.color))
        for ring in world.land {
            context.fill(morphed(ring, mapRect: mapRect, progress: progress), with: .color(paper))
        }
        for country in world.countries {
            var path = Path()
            for ring in country.rings {
                path.addPath(morphed(ring, mapRect: mapRect, progress: progress))
            }
            let facing = projection.view(GlobeSphere.vector(country.anchor.point)).z > 0
            var layer = context
            layer.opacity = facing ? 1 : progress
            layer.fill(path, with: .color(visited.contains(country.code) ? Palette.brand.color : paper))
            layer.stroke(path, with: .color(edge), lineWidth: 0.5)
        }
    }

    private func morphed(_ ring: GlobeRing, mapRect: CGRect, progress: Double) -> Path {
        var points: [CGPoint] = []
        points.reserveCapacity(ring.coarse.count)
        for (vector, flat) in zip(ring.coarse, ring.coarseFlat) {
            let view = projection.view(vector)
            let globe = view.z > 0 ? projection.screen(view) : projection.limb(view)
            let map = CGPoint(x: mapRect.minX + flat.x * mapRect.width, y: mapRect.minY + flat.y * mapRect.height)
            points.append(CGPoint(x: globe.x + (map.x - globe.x) * progress, y: globe.y + (map.y - globe.y) * progress))
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}
