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
            return Shape(code: country.code, path: shape, bounds: shape.boundingRect)
        }
        unassigned = catalog.unassignedLand.map { path([$0]) }
    }

    /// The country under a point in unit space, if any.
    func code(atUnit point: CGPoint) -> String? {
        countries.first { $0.bounds.contains(point) && $0.path.contains(point) }?.code
    }
}

/// The ink world map: every country as a paper cut-out, the ones you've been to flooded with
/// plum ink. Drawn on a Canvas from the bundled outlines, offline; no MapKit. Tap a country to
/// toggle it (when `onTap` is set).
struct InkWorldMap: View {
    let visited: Set<String>
    var onTap: ((String) -> Void)?
    private let world = InkWorld.shared

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let scale = CGAffineTransform(scaleX: size.width, y: size.height)
                let paper = Palette.surfaceRaised.color
                let edge = Palette.background.color
                for land in world.unassigned {
                    context.fill(land.applying(scale), with: .color(paper))
                }
                for country in world.countries {
                    let path = country.path.applying(scale)
                    let inked = visited.contains(country.code)
                    context.fill(path, with: .color(inked ? Palette.brand.color : paper))
                    context.stroke(path, with: .color(edge), lineWidth: 0.6)
                }
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
