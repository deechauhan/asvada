import CoreLocation
import DesignSystem
import Foundation
import Geo
import Model

/// What the Atlas shows and says, kept apart from the views so it's unit-tested (#49).
enum AtlasLogic {
    /// The countries you've been to: the ones stamped in the Countries collection (a café in
    /// Lisbon stamps Portugal there, so this covers every place you've logged).
    static func visitedCodes(items: [Item]) -> Set<String> {
        Set(items.filter { $0.collection?.kind == .countries }.compactMap { $0.countryCode?.uppercased() })
    }

    /// Every entry made in `code`, newest first: the country's own stamp and the cafés, films
    /// and so on logged there.
    static func entries(inCountry code: String, from entries: [Entry]) -> [Entry] {
        entries
            .filter { $0.item?.countryCode?.uppercased() == code.uppercased() }
            .sorted { $0.date > $1.date }
    }

    /// The line over the map: how much of the world is inked, or a ghost line before the first
    /// stamp (never a bare "0").
    static func headline(visited count: Int, worldTotal: Int = DrawerSummary.worldCountries) -> String {
        guard count > 0 else { return "Your countries will fill with ink here" }
        return PassportSpreadCard.title(count: count, worldTotal: worldTotal)
    }

    /// The country's outlines as map coordinates, one array per ring.
    static func rings(of country: Country) -> [[CLLocationCoordinate2D]] {
        country.outlines
            .filter { $0.count > 2 }
            .map { ring in ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } }
    }

    /// The country under a tap on the map, or nil over the open sea.
    static func country(at coordinate: CLLocationCoordinate2D, in catalog: CountryCatalog = .shared) -> Country? {
        catalog.country(at: GeoPoint(longitude: coordinate.longitude, latitude: coordinate.latitude))
    }

    /// "3 entries" / "1 entry".
    static func entryCount(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    /// What the sheet says when a country has nothing in it yet.
    static func emptyLine(for country: Country, isVisited: Bool) -> String {
        isVisited
            ? "Stamped, with nothing savoured in \(country.name) yet."
            : "Not stamped yet. Savour something in \(country.name), or stamp it from the Countries drawer."
    }
}
