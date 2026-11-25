import CoreGraphics
import Foundation
import Geo
import Model
import Sources
import Storage

/// Where a printed guess came from, as its source line says.
enum GuessSource: Equatable {
    case again
    case nearYou
    case nowShowing
    case youreIn
    case typed

    var title: String {
        switch self {
        case .again: "Again?"
        case .nearYou: "Near you"
        case .nowShowing: "Now showing"
        case .youreIn: "You're in"
        case .typed: "Top result"
        }
    }
}

/// What a guess stands for before it becomes an item in the drawer.
enum GuessSubject {
    case item(Item)
    case place(PlaceResult)
    case film(TMDBFilm)
    case country(Country)
    case airline(Airline)
}

/// One best guess, ready to print onto the blank.
struct Guess: Identifiable {
    let id: String
    let title: String
    let source: GuessSource
    let subject: GuessSubject
}

/// The print head (INTERACTION.md §5, steps 6–7): the drawn blank prints its best guess; tear it
/// off sideways for the next, swipe back to restore it.
struct PrintHead {
    private(set) var guesses: [Guess]
    private(set) var index = 0

    /// How far a sideways swipe must go, or how fast, to tear the guess off.
    static let tearDistance: CGFloat = 90
    static let tearSpeed: CGFloat = 650
    /// How long each character takes to print.
    static let perCharacter: TimeInterval = 0.02

    init(guesses: [Guess] = []) {
        self.guesses = guesses
    }

    /// The guess printed now, or nil once every guess has been torn off.
    var current: Guess? {
        guesses.indices.contains(index) ? guesses[index] : nil
    }

    /// "Again? · 1 of 3", or just the source when there's only one guess.
    var sourceLine: String? {
        guard let current else { return nil }
        guard guesses.count > 1 else { return current.source.title }
        return "\(current.source.title) · \(index + 1) of \(guesses.count)"
    }

    var canRestore: Bool {
        index > 0
    }

    /// Tears the printed guess off; the next one prints. False when there's nothing to tear.
    @discardableResult
    mutating func tear() -> Bool {
        guard current != nil else { return false }
        index += 1
        return true
    }

    /// Brings the last torn guess back.
    @discardableResult
    mutating func restore() -> Bool {
        guard canRestore else { return false }
        index -= 1
        return true
    }

    /// Adds guesses that arrived later (from the network, say) after the ones already there,
    /// leaving out repeats of the same thing.
    mutating func append(_ more: [Guess]) {
        let known = Set(guesses.map(\.id))
        guesses += more.filter { !known.contains($0.id) }
    }

    enum Swipe: Equatable {
        case tear
        case restore
        case none
    }

    /// A sideways swipe of `translation` points released at `velocity` points per second: left
    /// tears the guess off, right brings the last one back.
    static func swipe(translation: CGFloat, velocity: CGFloat) -> Swipe {
        if translation <= -tearDistance || velocity <= -tearSpeed {
            return .tear
        }
        if translation >= tearDistance || velocity >= tearSpeed {
            return .restore
        }
        return .none
    }

    /// The part of `text` printed after `elapsed` seconds, a character every `perCharacter`.
    static func printed(_ text: String, after elapsed: TimeInterval) -> String {
        let count = max(Int(elapsed / perCharacter), 0)
        return String(text.prefix(count))
    }
}

/// Where guesses come from, for one drawer.
@MainActor
enum Guesses {
    /// Again? The last few things savoured in this drawer.
    static func again(in collection: ExperienceCollection) -> [Guess] {
        let recent = (collection.items ?? []).filter { !($0.entries ?? []).isEmpty }
        return QuickLogFlow.matches(recent, query: "").prefix(3).map { item in
            Guess(id: "item:\(item.id)", title: item.name, source: .again, subject: .item(item))
        }
    }

    /// You're in: the country you're standing in, for the Countries drawer.
    static func youreIn(at point: GeoPoint, in collection: ExperienceCollection) -> [Guess] {
        guard collection.itemSource == .countryCatalog, let country = CountryCatalog.shared.country(at: point) else { return [] }
        return [Guess(id: "iso:\(country.code)", title: country.name, source: .youreIn, subject: .country(country))]
    }

    /// Near you: places of this drawer's kind within about 50 m.
    static func nearYou(at point: GeoPoint, in collection: ExperienceCollection, search: PlaceSearching) async -> [Guess] {
        guard let kind = placeKind(of: collection) else { return [] }
        let places = await (try? search.nearby(kind, around: point)) ?? []
        return places.prefix(3).map { place in
            Guess(id: place.externalRef, title: place.name, source: .nearYou, subject: .place(place))
        }
    }

    /// Now showing: films in cinemas, for the Films drawer (needs the TMDB key).
    static func nowShowing(in collection: ExperienceCollection, tmdb: TMDBClient) async -> [Guess] {
        guard collection.itemSource == .tmdb else { return [] }
        let films = await (try? tmdb.nowShowing()) ?? []
        return films.prefix(3).map { film in
            Guess(id: film.externalRef, title: film.title, source: .nowShowing, subject: .film(film))
        }
    }

    /// The top result for what's been typed: the drawer's own items first, then the catalogue
    /// or search for its kind of thing.
    static func top(
        for query: String,
        in collection: ExperienceCollection,
        near point: GeoPoint?,
        search: PlaceSearching,
        tmdb: TMDBClient,
    ) async -> Guess? {
        await results(for: query, in: collection, near: point, search: search, tmdb: tmdb).top
    }

    /// Everything typing finds: the drawer's matches, then the source's results, numbered.
    static func results(
        for query: String,
        in collection: ExperienceCollection,
        near point: GeoPoint?,
        search: PlaceSearching,
        tmdb: TMDBClient,
    ) async -> SearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let items = collection.items ?? []
        return await SearchResults.make(
            matches: Array(QuickLogFlow.matches(items, query: trimmed).prefix(6)),
            online: found(for: trimmed, in: collection, near: point, search: search, tmdb: tmdb),
            in: items,
            near: point,
        )
    }

    /// What the collection's source finds for `query` (not yet de-duplicated or capped).
    private static func found(
        for query: String,
        in collection: ExperienceCollection,
        near point: GeoPoint?,
        search: PlaceSearching,
        tmdb: TMDBClient,
    ) async -> [Guess] {
        switch collection.itemSource {
        case .countryCatalog:
            return CountryCatalog.shared.search(query).map {
                Guess(id: "iso:\($0.code)", title: $0.name, source: .typed, subject: .country($0))
            }
        case .airlineCatalog:
            return AirlineCatalog.shared.search(query).map {
                Guess(id: "iata:\($0.iata)", title: $0.name, source: .typed, subject: .airline($0))
            }
        case .tmdb:
            return await ((try? tmdb.searchFilms(query)) ?? []).map {
                Guess(id: $0.externalRef, title: $0.title, source: .typed, subject: .film($0))
            }
        case .mapkit:
            guard let kind = placeKind(of: collection) else { return [] }
            return await ((try? search.search(query, kind: kind, near: point)) ?? []).map {
                Guess(id: $0.externalRef, title: $0.name, source: .typed, subject: .place($0))
            }
        case .manual:
            return []
        }
    }

    /// The item a guess stands for, adding it to the drawer if it isn't there yet.
    static func accept(_ guess: Guess, in collection: ExperienceCollection, repository: Repository) -> Item {
        switch guess.subject {
        case let .item(item):
            return item
        case let .place(place):
            return repository.upsertPlace(
                PlaceDetails(
                    name: place.name,
                    externalRef: place.externalRef,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    countryCode: place.countryCode,
                    address: place.address,
                ),
                in: collection,
            )
        case let .film(film):
            return repository.upsertItem(named: film.title, externalRef: film.externalRef, in: collection)
        case let .country(country):
            let item = repository.upsertItem(named: country.name, externalRef: "iso:\(country.code)", in: collection)
            item.countryCode = country.code
            return item
        case let .airline(airline):
            return repository.upsertItem(named: airline.name, externalRef: "iata:\(airline.iata)", in: collection)
        }
    }

    static func placeKind(of collection: ExperienceCollection) -> PlaceKind? {
        switch collection.kind {
        case .cafes: .cafe
        case .restaurants: .restaurant
        case .cities: .city
        default: collection.itemSource == .mapkit ? .any : nil
        }
    }
}
