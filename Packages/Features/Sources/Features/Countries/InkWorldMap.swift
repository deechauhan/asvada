import DesignSystem
import Geo
import SwiftUI

/// Every country projected once (Robinson) into unit space, ready to scale to any size. Building
/// the paths is the expensive part, so it happens once and the map only scales them per frame.
struct InkWorld: Sendable {
    /// One country's outline in unit space (x and y in 0...1, north at the top).
    struct Shape: Sendable {
        let code: String
        let path: Path
        let bounds: CGRect
        /// Where the reticle sits on it: the middle of its largest outline, so the United States
        /// is aimed at the lower 48, not halfway to Alaska.
        let anchor: CGPoint
    }

    static let shared = InkWorld(catalog: .shared)

    /// The map is cropped to these latitudes: the Arctic coast to just below Cape Horn.
    static let north = 84.0
    static let south = -58.0

    let countries: [Shape]
    let unassigned: [Path]
    /// Width over height of the cropped map.
    let aspectRatio: CGFloat

    init(catalog: CountryCatalog) {
        let top = Robinson.project(GeoPoint(longitude: 0, latitude: Self.north)).y
        let bottom = Robinson.project(GeoPoint(longitude: 0, latitude: Self.south)).y
        let height = top - bottom
        aspectRatio = 2 / height
        func unit(_ point: GeoPoint) -> CGPoint {
            let projected = Robinson.project(point)
            return CGPoint(x: (projected.x + 1) / 2, y: (top - projected.y) / height)
        }
        func path(_ rings: [[GeoPoint]]) -> Path {
            var path = Path()
            for ring in rings where ring.count > 2 {
                path.addLines(ring.map(unit))
                path.closeSubpath()
            }
            return path
        }
        // Antarctica would be a white band along the bottom of a cropped map; leave it out.
        countries = catalog.countries.filter { $0.code != "AQ" }.map { country in
            let shape = path(country.outlines)
            let largest = country.outlines
                .map { path([$0]).boundingRect }
                .max { $0.width * $0.height < $1.width * $1.height } ?? shape.boundingRect
            return Shape(
                code: country.code,
                path: shape,
                bounds: shape.boundingRect,
                anchor: CGPoint(x: largest.midX, y: largest.midY),
            )
        }
        unassigned = catalog.unassignedLand.map { path([$0]) }
        byCode = Dictionary(countries.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private let byCode: [String: Shape]

    /// The drawn shape for ISO code `code`, if the map draws it.
    func shape(code: String) -> Shape? {
        byCode[code.uppercased()]
    }

    /// The country under a point in unit space, if any. Outlines are outer rings only, so where
    /// they overlap (Lesotho inside South Africa) the smallest wins.
    func code(atUnit point: CGPoint) -> String? {
        countries
            .filter { $0.bounds.contains(point) && $0.path.contains(point) }
            .min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }?
            .code
    }

    /// Draws the map into `context`: unassigned land, then every country, inked if it's in
    /// `visited`. `transform` maps unit space to the context (scale, plus a shift for the loupe).
    func draw(in context: GraphicsContext, transform: CGAffineTransform, visited: Set<String>) {
        // Unvisited land needs enough tone to read as a map before anything is inked.
        let paper = Palette.separator.color
        let edge = Palette.background.color
        for land in unassigned {
            context.fill(land.applying(transform), with: .color(paper))
        }
        for country in countries {
            let path = country.path.applying(transform)
            let inked = visited.contains(country.code)
            context.fill(path, with: .color(inked ? Palette.brand.color : paper))
            context.stroke(path, with: .color(edge), lineWidth: 0.6)
        }
    }
}

/// The ink world map: every country as a paper cut-out, the ones you've been to flooded with
/// plum ink. Drawn on a Canvas from the bundled outlines, offline; no MapKit. Tap a country to
/// toggle it (when `onTap` is set).
struct InkWorldMap: View {
    let visited: Set<String>
    /// A visited country to leave as paper for now: the stamp pad blooms its ink in on top.
    var unInked: String?
    var onTap: ((String) -> Void)?
    private let world = InkWorld.shared

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let inked = unInked.map { visited.subtracting([$0]) } ?? visited
                world.draw(in: context, transform: CGAffineTransform(scaleX: size.width, y: size.height), visited: inked)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let onTap, proxy.size.width > 0, proxy.size.height > 0 else { return }
                let point = CGPoint(x: location.x / proxy.size.width, y: location.y / proxy.size.height)
                if let code = world.code(atUnit: point) {
                    onTap(code)
                }
            }
        }
        .aspectRatio(world.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(visited: visited))
        .accessibilityIdentifier("inkWorldMap")
    }

    /// What VoiceOver says: how many countries are inked, and which.
    static func summary(visited: Set<String>) -> String {
        guard !visited.isEmpty else { return "World map, no countries inked yet" }
        let names = visited.compactMap { CountryCatalog.shared.country(code: $0)?.name }.sorted()
        let noun = visited.count == 1 ? "country" : "countries"
        return "World map, \(visited.count) \(noun) inked: \(names.formatted(.list(type: .and)))"
    }
}

#Preview {
    InkWorldMap(visited: ["JP", "PT", "PE", "KE", "IN", "IS"])
        .padding()
}
