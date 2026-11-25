import Foundation
import Geo
import Model
import Sources
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct SearchResultsTests {
    private static let soho = GeoPoint(longitude: -0.1340, latitude: 51.5136)

    private func place(_ name: String, _ latitude: Double, _ longitude: Double, address: String? = nil) -> Guess {
        let result = PlaceResult(name: name, latitude: latitude, longitude: longitude, address: address, mapItemIdentifier: name)
        return Guess(id: result.externalRef, title: name, source: .typed, subject: .place(result))
    }

    /// An in-memory store with the built-ins. Hold on to it for the whole test: the context stops
    /// working once its container is released.
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let cafes: ExperienceCollection
    }

    private func seededStore() throws -> Store {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        return Store(container: container, repository: repository, cafes: cafes)
    }

    @Test func resultsAreNumberedFromOneAndCapped() {
        let online = (1 ... 12).map { place("Café \($0)", 51.5, -0.1) }
        let results = SearchResults.make(matches: [], online: online, in: [], near: nil)
        #expect(results.found.map(\.number) == Array(1 ... SearchResults.limit))
        #expect(results.found.first?.title == "Café 1")
        #expect(results.top?.title == "Café 1")
    }

    @Test func aResultTheDrawerAlreadyHoldsIsShownOnceAsTheDrawersOwn() throws {
        let store = try seededStore()
        let (repository, cafes) = (store.repository, store.cafes)
        let held = repository.upsertItem(named: "Monmouth Coffee", externalRef: "mk:Monmouth Coffee", in: cafes)
        let online = [place("Monmouth Coffee", 51.5143, -0.1268), place("Prufrock Coffee", 51.5199, -0.1092)]

        let results = SearchResults.make(matches: [], online: online, in: cafes.items ?? [], near: nil)

        #expect(results.drawer.map(\.id) == [held.id])
        #expect(results.found.map(\.title) == ["Prufrock Coffee"])
        #expect(results.found.first?.number == 1)
        // The drawer's own thing prints first.
        #expect(results.top?.title == "Monmouth Coffee")
        #expect(results.top?.id == "item:\(held.id)")
    }

    @Test func aMatchByNameIsntListedTwice() throws {
        let store = try seededStore()
        let (repository, cafes) = (store.repository, store.cafes)
        let held = repository.upsertItem(named: "Monmouth Coffee", externalRef: "mk:Monmouth Coffee", in: cafes)
        let results = SearchResults.make(
            matches: [held],
            online: [place("Monmouth Coffee", 51.5143, -0.1268)],
            in: cafes.items ?? [],
            near: nil,
        )
        #expect(results.drawer.count == 1)
        #expect(results.found.isEmpty)
    }

    @Test func placesSayWhereTheyAreAndHowFar() throws {
        let monmouth = place("Monmouth Coffee", 51.5143, -0.1268, address: "27 Monmouth St, London")
        let results = SearchResults.make(matches: [], online: [monmouth], in: [], near: Self.soho)
        let row = try #require(results.found.first)
        #expect(row.subtitle?.hasPrefix("27 Monmouth St, London · ") == true)
        #expect(row.point == GeoPoint(longitude: -0.1268, latitude: 51.5143))
        #expect(row.spokenLabel.hasPrefix("1. Monmouth Coffee, 27 Monmouth St, London") == true)
        #expect(results.hasPlaces)
        // Without knowing where you are, just the address.
        let anywhere = SearchResults.make(matches: [], online: [monmouth], in: [], near: nil)
        #expect(anywhere.found.first?.subtitle == "27 Monmouth St, London")
    }

    @Test func distanceIsAboutRight() {
        // Soho to Monmouth Street is about half a kilometre.
        let metres = SearchResults.metres(from: Self.soho, to: GeoPoint(longitude: -0.1268, latitude: 51.5143))
        #expect(metres > 450 && metres < 600)
        // London to Lisbon is about 1,585 km.
        let lisbon = SearchResults.metres(
            from: GeoPoint(longitude: -0.1276, latitude: 51.5072),
            to: GeoPoint(longitude: -9.1393, latitude: 38.7223),
        )
        #expect(abs(lisbon - 1_585_000) < 20000)
    }

    @Test func filmsShowTheirYearAndCatalogueRowsTheirCode() throws {
        let json = Data(#"{"id": 976893, "title": "Perfect Days", "release_date": "2023-12-21", "poster_path": null}"#.utf8)
        let film = try JSONDecoder().decode(TMDBFilm.self, from: json)
        #expect(SearchResults.subtitle(for: .film(film), near: nil) == "2023")
        let japan = try #require(CountryCatalog.shared.search("Japan").first)
        #expect(SearchResults.subtitle(for: .country(japan), near: nil) == japan.flag)
        #expect(SearchResults.location(of: .film(film)) == nil)
    }

    @Test func eachSourceIsNamed() {
        #expect(SearchResults.sourceTitle(for: .mapkit) == "From Apple Maps")
        #expect(SearchResults.sourceTitle(for: .tmdb) == "From TMDB")
        #expect(SearchResults.sourceTitle(for: .countryCatalog) == "From the catalogue")
        #expect(SearchResults.sourceTitle(for: .manual) == nil)
    }

    @Test func typingInCafesListsSamplePlacesAfterTheDrawersOwn() async throws {
        let store = try seededStore()
        let (repository, cafes) = (store.repository, store.cafes)
        repository.upsertItem(named: "Corner Coffee", externalRef: nil, in: cafes)
        let results = await Guesses.results(
            for: "coffee",
            in: cafes,
            near: nil,
            search: SamplePlaceSearch(),
            tmdb: TMDBClient(configuration: nil),
        )
        #expect(results.drawer.map(\.name) == ["Corner Coffee"])
        #expect(results.found.map(\.title) == ["Monmouth Coffee", "Prufrock Coffee", "Workshop Coffee", "Origin Coffee"])
        #expect(results.top?.title == "Corner Coffee")
    }
}
