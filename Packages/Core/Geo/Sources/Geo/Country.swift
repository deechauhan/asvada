import Foundation

/// A longitude/latitude pair in degrees.
public struct GeoPoint: Sendable, Hashable {
    public let longitude: Double
    public let latitude: Double

    public init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }
}

/// The continents the catalog groups countries by (Natural Earth's, with the Americas split).
public enum Continent: String, CaseIterable, Sendable, Codable {
    case africa = "Africa"
    case antarctica = "Antarctica"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case oceania = "Oceania"
    case southAmerica = "South America"

    public var name: String {
        rawValue
    }
}

/// A country in the bundled catalog.
public struct Country: Sendable, Hashable, Identifiable {
    /// ISO 3166-1 alpha-2, e.g. "JP" (Kosovo uses the user-assigned "XK").
    public let code: String
    /// ISO 3166-1 alpha-3, e.g. "JPN".
    public let code3: String
    public let name: String
    public let continent: Continent
    /// Simplified outer outlines (islands and exclaves are separate rings), largest first.
    public let outlines: [[GeoPoint]]
    /// The outlines' bounding box, for quick rejection in hit-testing.
    public let bounds: GeoBounds

    public var id: String {
        code
    }

    /// The flag emoji, built from the code's regional-indicator letters ("JP" → 🇯🇵).
    public var flag: String {
        Self.flag(for: code)
    }

    public static func flag(for code: String) -> String {
        let base: UInt32 = 0x1F1E6 - 65 // regional indicator A minus "A"
        let scalars = code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }
        return scalars.count == 2 ? String(String.UnicodeScalarView(scalars)) : ""
    }

    /// Whether `point` falls inside one of the country's outlines.
    public func contains(_ point: GeoPoint) -> Bool {
        bounds.contains(point) && outlines.contains { Self.ring($0, contains: point) }
    }

    /// The shortest distance from `point` to the country's outline, in kilometres (an
    /// equirectangular approximation; good to a few percent at the distances that matter here).
    public func distanceInKilometres(to point: GeoPoint) -> Double {
        let scale = cos(point.latitude * .pi / 180)
        func flat(_ geo: GeoPoint) -> (x: Double, y: Double) {
            (geo.longitude * 111.32 * scale, geo.latitude * 110.57)
        }
        let target = flat(point)
        var best = Double.infinity
        for ring in outlines where ring.count > 1 {
            var previous = flat(ring[ring.count - 1])
            for geo in ring {
                let current = flat(geo)
                best = min(best, Self.distance(from: target, toSegment: previous, current))
                previous = current
            }
        }
        return best
    }

    /// Distance from `point` to the segment `start`–`end` in the plane.
    static func distance(
        from point: (x: Double, y: Double),
        toSegment start: (x: Double, y: Double),
        _ end: (x: Double, y: Double),
    ) -> Double {
        let runX = end.x - start.x
        let runY = end.y - start.y
        let lengthSquared = runX * runX + runY * runY
        let fraction = lengthSquared == 0
            ? 0
            : min(max(((point.x - start.x) * runX + (point.y - start.y) * runY) / lengthSquared, 0), 1)
        return hypot(point.x - (start.x + fraction * runX), point.y - (start.y + fraction * runY))
    }

    /// Even-odd ray casting.
    static func ring(_ ring: [GeoPoint], contains point: GeoPoint) -> Bool {
        var inside = false
        var previous = ring.count - 1
        for current in ring.indices {
            let here = ring[current]
            let last = ring[previous]
            if (here.latitude > point.latitude) != (last.latitude > point.latitude) {
                // Where this edge crosses the point's latitude.
                let slope = (last.longitude - here.longitude) / (last.latitude - here.latitude)
                let crossing = here.longitude + slope * (point.latitude - here.latitude)
                if point.longitude < crossing {
                    inside.toggle()
                }
            }
            previous = current
        }
        return inside
    }
}

/// A longitude/latitude rectangle.
public struct GeoBounds: Sendable, Hashable {
    public let minLongitude: Double
    public let minLatitude: Double
    public let maxLongitude: Double
    public let maxLatitude: Double

    init(minLongitude: Double, minLatitude: Double, maxLongitude: Double, maxLatitude: Double) {
        self.minLongitude = minLongitude
        self.minLatitude = minLatitude
        self.maxLongitude = maxLongitude
        self.maxLatitude = maxLatitude
    }

    init(_ rings: [[GeoPoint]]) {
        let points = rings.joined()
        minLongitude = points.map(\.longitude).min() ?? 0
        maxLongitude = points.map(\.longitude).max() ?? 0
        minLatitude = points.map(\.latitude).min() ?? 0
        maxLatitude = points.map(\.latitude).max() ?? 0
    }

    public func contains(_ point: GeoPoint) -> Bool {
        (minLongitude ... maxLongitude).contains(point.longitude) && (minLatitude ... maxLatitude).contains(point.latitude)
    }

    /// The box's area in square degrees (for comparing sizes, not for measuring land).
    public var area: Double {
        (maxLongitude - minLongitude) * (maxLatitude - minLatitude)
    }

    /// The box grown by `degrees` on every side.
    public func expanded(by degrees: Double) -> GeoBounds {
        GeoBounds(
            minLongitude: minLongitude - degrees,
            minLatitude: minLatitude - degrees,
            maxLongitude: maxLongitude + degrees,
            maxLatitude: maxLatitude + degrees,
        )
    }
}
