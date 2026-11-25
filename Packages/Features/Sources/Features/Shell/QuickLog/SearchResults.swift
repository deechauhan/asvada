import Foundation
import Geo
import Model
import Sources
import SwiftUI

/// What typing in quick-log finds, in two groups: things already in the drawer, then up to
/// `limit` from the collection's source (Apple Maps, TMDB or a bundled catalogue), numbered so
/// the map's pins match the list. A source result that's already in the drawer is shown once, as
/// the drawer's own thing.
struct SearchResults {
    /// One numbered result from the source.
    struct Found: Identifiable {
        let number: Int
        let guess: Guess
        let subtitle: String?
        /// Where it is, for places.
        let point: GeoPoint?

        var id: String {
            guess.id
        }

        var title: String {
            guess.title
        }

        /// "2. Monmouth Coffee, 27 Monmouth St, London, 300 m" for VoiceOver.
        var spokenLabel: String {
            ["\(number). \(title)", subtitle].compactMap(\.self).joined(separator: ", ")
        }
    }

    /// The most results listed from the source.
    static let limit = 8

    /// Things already in the drawer that match.
    var drawer: [Item]
    var found: [Found]

    static let empty = SearchResults(drawer: [], found: [])

    /// Groups `online` results after the drawer's `matches`, moving any result the collection
    /// already holds (same `externalRef`) into the drawer group, and numbering the rest from 1.
    static func make(
        matches: [Item],
        online: [Guess],
        in items: [Item],
        near point: GeoPoint?,
        limit: Int = limit,
    ) -> SearchResults {
        var drawer = matches
        var found: [Found] = []
        for guess in online {
            if let held = items.first(where: { $0.externalRef != nil && $0.externalRef == guess.id }) {
                if !drawer.contains(where: { $0.id == held.id }) {
                    drawer.append(held)
                }
                continue
            }
            guard found.count < limit, !found.contains(where: { $0.id == guess.id }) else { continue }
            found.append(Found(
                number: found.count + 1,
                guess: guess,
                subtitle: subtitle(for: guess.subject, near: point),
                point: location(of: guess.subject),
            ))
        }
        return SearchResults(drawer: drawer, found: found)
    }

    /// The best thing to print onto the blank: the drawer's first match, else the first result.
    var top: Guess? {
        if let item = drawer.first {
            return Guess(id: "item:\(item.id)", title: item.name, source: .typed, subject: .item(item))
        }
        return found.first?.guess
    }

    /// Whether any result has a place to put on a map.
    var hasPlaces: Bool {
        found.contains { $0.point != nil }
    }

    /// "From Apple Maps", "From TMDB" or "From the catalogue".
    static func sourceTitle(for source: ItemSource) -> String? {
        switch source {
        case .mapkit: "From Apple Maps"
        case .tmdb: "From TMDB"
        case .countryCatalog, .airlineCatalog: "From the catalogue"
        case .manual: nil
        }
    }

    /// The address and how far away for a place, the year for a film, the code for an airline.
    static func subtitle(for subject: GuessSubject, near point: GeoPoint?) -> String? {
        switch subject {
        case let .place(place):
            let distance = point.map {
                distanceText(metres: metres(from: $0, to: GeoPoint(longitude: place.longitude, latitude: place.latitude)))
            }
            let parts = [place.address, distance].compactMap(\.self)
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case let .film(film):
            return film.year.map(String.init)
        case let .country(country):
            return country.flag
        case let .airline(airline):
            return airline.iata
        case .item:
            return nil
        }
    }

    static func location(of subject: GuessSubject) -> GeoPoint? {
        guard case let .place(place) = subject else { return nil }
        return GeoPoint(longitude: place.longitude, latitude: place.latitude)
    }

    /// Great-circle distance in metres (haversine).
    static func metres(from start: GeoPoint, to end: GeoPoint) -> Double {
        let radians = Double.pi / 180
        let latitudeDelta = (end.latitude - start.latitude) * radians
        let longitudeDelta = (end.longitude - start.longitude) * radians
        let chord = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(start.latitude * radians) * cos(end.latitude * radians) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return 6_371_000 * 2 * atan2(sqrt(chord), sqrt(1 - chord))
    }

    /// "300 m", "1.2 km", "45 km" in the user's units.
    static func distanceText(metres: Double) -> String {
        let style = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            usage: .road,
            numberFormatStyle: .number.precision(.significantDigits(2)),
        )
        return Measurement(value: metres, unit: UnitLength.meters).formatted(style)
    }
}

/// Whether quick-log shows place results as a list or on a map. Remembered per collection.
enum ResultsLayout: String, CaseIterable {
    case list
    case map

    var title: String {
        switch self {
        case .list: "List"
        case .map: "Map"
        }
    }

    static func storageKey(for collection: ExperienceCollection) -> String {
        "quickLog.resultsLayout.\(collection.id.uuidString)"
    }
}

public extension EnvironmentValues {
    /// Where quick-log looks places up: Apple Maps, or fixed samples under `-samplePlaces`.
    @Entry var placeSearch: any PlaceSearching = MapKitPlaceSearch()
}

public extension View {
    /// Searches the fixed sample places instead of Apple Maps (UI tests and screenshots).
    func searchingSamplePlaces() -> some View {
        environment(\.placeSearch, SamplePlaceSearch())
    }
}
