import CoreLocation
import DesignSystem
import Foundation
import Geo
import MapKit
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

    // MARK: - Pins

    /// Pins show once the map is zoomed in to about this many degrees of latitude (a country or two).
    static let pinZoom = 30.0
    /// The most pins drawn at once, nearest the middle first, so a crowded view stays quick.
    static let pinLimit = 300

    /// Whether the map is zoomed in far enough to show individual places.
    static func showsPins(latitudeSpan: Double) -> Bool {
        latitudeSpan > 0 && latitudeSpan <= pinZoom
    }

    /// The places to pin in `region`: items with a position and at least one entry, outside the
    /// Countries drawer (a country is ink, not a pin), nearest the middle first.
    static func pins(items: [Item], in region: AtlasRegion, limit: Int = pinLimit) -> [Item] {
        items
            .compactMap { item -> (item: Item, distance: Double)? in
                guard
                    item.collection?.kind != .countries,
                    let latitude = item.latitude, let longitude = item.longitude,
                    !(item.entries ?? []).isEmpty,
                    region.contains(latitude: latitude, longitude: longitude)
                else { return nil }
                return (item, region.distance(latitude: latitude, longitude: longitude))
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0.item }
    }

    /// "Savoured 3 times, last 12 Nov 2026" / "Savoured once, 4 Mar 2026" / a ghost line.
    static func visitLine(entryDates: [Date]) -> String {
        guard let last = entryDates.max() else { return "Nothing savoured here yet." }
        let when = last.formatted(date: .abbreviated, time: .omitted)
        return entryDates.count == 1 ? "Savoured once, \(when)" : "Savoured \(entryDates.count) times, last \(when)"
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

/// The part of the world the map is showing: a middle and how far it spans each way.
struct AtlasRegion: Equatable {
    let centreLatitude: Double
    let centreLongitude: Double
    let latitudeSpan: Double
    let longitudeSpan: Double

    /// Whether a place is inside, wrapping round the antimeridian.
    func contains(latitude: Double, longitude: Double) -> Bool {
        abs(latitude - centreLatitude) <= latitudeSpan / 2 && abs(offset(longitude)) <= longitudeSpan / 2
    }

    /// Degrees from the middle, for ordering (longitude shrinks towards the poles).
    func distance(latitude: Double, longitude: Double) -> Double {
        let across = offset(longitude) * cos(centreLatitude * .pi / 180)
        return hypot(latitude - centreLatitude, across)
    }

    /// The signed longitude gap to the middle, the short way round.
    private func offset(_ longitude: Double) -> Double {
        var gap = (longitude - centreLongitude).truncatingRemainder(dividingBy: 360)
        if gap > 180 {
            gap -= 360
        } else if gap < -180 {
            gap += 360
        }
        return gap
    }
}

extension AtlasRegion {
    /// The region a map camera shows.
    init(_ region: MKCoordinateRegion) {
        self.init(
            centreLatitude: region.center.latitude,
            centreLongitude: region.center.longitude,
            latitudeSpan: region.span.latitudeDelta,
            longitudeSpan: region.span.longitudeDelta,
        )
    }
}
