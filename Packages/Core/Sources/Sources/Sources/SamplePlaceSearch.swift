import Foundation
import Geo

/// A fixed handful of London places (and a few cities) instead of Apple Maps, so UI tests and
/// screenshots see the same results every time and need no network (`-samplePlaces`).
public struct SamplePlaceSearch: PlaceSearching {
    public init() {}

    /// Every sample place, by the kind of search that finds it.
    public static let places: [PlaceKind: [PlaceResult]] = [
        .cafe: [
            sample("Monmouth Coffee", 51.5143, -0.1268, "27 Monmouth St, London"),
            sample("Prufrock Coffee", 51.5199, -0.1092, "23–25 Leather Ln, London"),
            sample("Workshop Coffee", 51.5184, -0.1528, "80A Mortimer St, London"),
            sample("Kaffeine", 51.5191, -0.1395, "66 Great Titchfield St, London"),
            sample("Origin Coffee", 51.5247, -0.0823, "65 Charlotte Rd, London"),
        ],
        .restaurant: [
            sample("Dishoom Covent Garden", 51.5124, -0.1268, "12 Upper St Martin's Ln, London"),
            sample("Padella", 51.5054, -0.0910, "6 Southwark St, London"),
            sample("St. JOHN", 51.5204, -0.1016, "26 St John St, London"),
        ],
        .city: [
            sample("London", 51.5072, -0.1276, "England, United Kingdom"),
            sample("Lisbon", 38.7223, -9.1393, "Portugal"),
            sample("Kyoto", 35.0116, 135.7681, "Japan"),
        ],
    ]

    public func search(_ query: String, kind: PlaceKind, near _: GeoPoint?) async throws -> [PlaceResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let pool = kind == .any ? Self.places.values.flatMap(\.self) : Self.places[kind] ?? []
        // "Search this area" with nothing typed asks for the kind itself: every sample of it.
        if needle.compare(kind.searchWord, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return pool
        }
        return pool.filter { $0.name.localizedStandardContains(needle) || ($0.address ?? "").localizedStandardContains(needle) }
    }

    public func nearby(_: PlaceKind, around _: GeoPoint) async throws -> [PlaceResult] {
        []
    }

    /// The sample city within about 100 km of `point`, if any.
    public func city(at point: GeoPoint) async throws -> PlaceResult? {
        let cities = Self.places[.city] ?? []
        return cities
            .map { ($0, MapKitPlaceSearch.kilometres(from: point, to: $0)) }
            .filter { $0.1 < 100 }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func sample(_ name: String, _ latitude: Double, _ longitude: Double, _ address: String) -> PlaceResult {
        let slug = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return PlaceResult(
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            countryCode: nil,
            mapItemIdentifier: "sample-\(slug)",
        )
    }
}
