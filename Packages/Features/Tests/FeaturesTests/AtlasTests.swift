import CoreLocation
import Foundation
import Geo
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct AtlasTests {
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let cafes: ExperienceCollection
        let countries: ExperienceCollection
    }

    private func store() throws -> Store {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        let cafes = ExperienceCollection(name: "Cafés", kind: .cafes, ratingMode: .ranked)
        let countries = ExperienceCollection(name: "Countries", kind: .countries, ratingMode: .checklist)
        repository.context.insert(cafes)
        repository.context.insert(countries)
        return Store(container: container, repository: repository, cafes: cafes, countries: countries)
    }

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: 1_000_000).addingTimeInterval(Double(offset) * 86400)
    }

    /// An entry made directly, without `addEntry` also stamping the item's country.
    @discardableResult
    private func log(_ item: Item, on date: Date, in store: Store) -> Entry {
        let entry = Entry(date: date)
        store.repository.context.insert(entry)
        entry.item = item
        return entry
    }

    @Test func visitedCountriesAreTheStampedOnesAndNothingElse() throws {
        let store = try store()
        try store.repository.setStamped(["pt", "JP"], in: store.countries)
        let cafe = store.repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        cafe.countryCode = "FR"
        let items = try store.repository.context.fetch(FetchDescriptor<Item>())
        #expect(AtlasLogic.visitedCodes(items: items) == ["PT", "JP"])
    }

    @Test func aPlaceStampsItsCountryForTheAtlas() throws {
        let store = try store()
        let cafe = store.repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        cafe.latitude = 38.7
        cafe.longitude = -9.14
        store.repository.stampCountry(of: cafe)
        let items = try store.repository.context.fetch(FetchDescriptor<Item>())
        #expect(AtlasLogic.visitedCodes(items: items) == ["PT"])
    }

    @Test func aCountrysEntriesIncludeItsStampAndThePlacesInIt_NewestFirst() throws {
        let store = try store()
        let repository = store.repository
        try repository.setStamped(["PT"], in: store.countries)
        let stamp = try #require(store.countries.items?.first)
        let stampEntry = log(stamp, on: day(0), in: store)
        let lisbon = repository.upsertItem(named: "Pastéis", externalRef: nil, in: store.cafes)
        lisbon.countryCode = "PT"
        let cafeEntry = log(lisbon, on: day(3), in: store)
        let paris = repository.upsertItem(named: "Café de Flore", externalRef: nil, in: store.cafes)
        paris.countryCode = "FR"
        log(paris, on: day(5), in: store)

        let all = try repository.context.fetch(FetchDescriptor<Entry>())
        let found = AtlasLogic.entries(inCountry: "pt", from: all)
        #expect(found.map(\.id) == [cafeEntry.id, stampEntry.id])
        #expect(AtlasLogic.entries(inCountry: "FR", from: all).count == 1)
        #expect(AtlasLogic.entries(inCountry: "JP", from: all).isEmpty)
    }

    @Test func theHeadlineIsAGhostLineUntilTheFirstStamp() {
        #expect(AtlasLogic.headline(visited: 0) == "Your countries will fill with ink here")
        #expect(AtlasLogic.headline(visited: 8, worldTotal: 200) == "8 countries · 4% of the world")
        #expect(!AtlasLogic.headline(visited: 0).contains("0"))
    }

    @Test func aCountryTurnsIntoCoordinateRings() throws {
        let japan = try #require(CountryCatalog.shared.country(code: "JP"))
        let rings = AtlasLogic.rings(of: japan)
        #expect(rings.count > 1)
        #expect(rings.allSatisfy { $0.count > 2 })
        let first = try #require(japan.outlines.first?.first)
        #expect(rings.first?.first?.latitude == first.latitude)
        #expect(rings.first?.first?.longitude == first.longitude)
    }

    @Test func aTapFindsTheCountryUnderIt() {
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 38.7, longitude: -9.14))?.code == "PT")
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 36, longitude: 139))?.code == "JP")
        // Mid-Atlantic.
        #expect(AtlasLogic.country(at: CLLocationCoordinate2D(latitude: 30, longitude: -40)) == nil)
    }

    @Test func theSheetSaysWhatIsMissingNotAZero() throws {
        let portugal = try #require(CountryCatalog.shared.country(code: "PT"))
        #expect(AtlasLogic.entryCount(1) == "1 entry")
        #expect(AtlasLogic.entryCount(3) == "3 entries")
        #expect(AtlasLogic.emptyLine(for: portugal, isVisited: true).contains("Stamped"))
        #expect(AtlasLogic.emptyLine(for: portugal, isVisited: false).contains("Not stamped yet"))
    }
}
