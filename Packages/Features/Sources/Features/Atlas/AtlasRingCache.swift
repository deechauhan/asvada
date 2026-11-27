import CoreLocation
import Geo

/// The map's polygon coordinates, built once per country (#53). Turning a country's outlines
/// into coordinates is the heavy part of drawing the ink (Canada has about 8,000 points), and
/// the map's body runs on every pan, zoom and filter change, so what's built is kept.
@MainActor
enum AtlasRingCache {
    private static var rings: [String: [[CLLocationCoordinate2D]]] = [:]

    /// How many countries are held.
    static var countriesHeld: Int {
        rings.count
    }

    /// `country`'s rings, from the cache when it has them.
    static func rings(of country: Country) -> [[CLLocationCoordinate2D]] {
        if let cached = rings[country.code] {
            return cached
        }
        let built = AtlasLogic.rings(of: country)
        rings[country.code] = built
        return built
    }

    /// Empties the cache (tests, and a memory warning).
    static func clear() {
        rings.removeAll()
    }
}
