import Foundation
import Geo
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct ManualItemTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func collection(_ kind: CollectionKind) throws -> ExperienceCollection {
        let match = try repository.collections().first { $0.kind == kind }
        return try #require(match)
    }

    @Test func aNameIsAllItNeeds() throws {
        let films = try collection(.films)
        let item = try repository.addManualItem(ManualItemDraft(name: "  Home movie, 1998 \n"), in: films)
        #expect(item.name == "Home movie, 1998")
        #expect(item.externalRef == nil)
        #expect(item.latitude == nil)
        #expect(item.countryCode == nil)
        #expect(films.items?.contains(item) == true)
    }

    @Test func aBlankNameIsRefused() throws {
        let cafes = try collection(.cafes)
        #expect(throws: ManualItemError.emptyName) {
            try repository.addManualItem(ManualItemDraft(name: "   "), in: cafes)
        }
        #expect(!ManualItemDraft(name: "\n").isValid)
        #expect(ManualItemDraft(name: "Kiosk").isValid)
    }

    @Test func aPinGivesItCoordinatesAndACountry() throws {
        let cafes = try collection(.cafes)
        let lisbon = GeoPoint(longitude: -9.14, latitude: 38.71)
        let item = try repository.addManualItem(ManualItemDraft(name: "Corner kiosk", location: lisbon), in: cafes)
        #expect(item.latitude == 38.71)
        #expect(item.longitude == -9.14)
        #expect(item.countryCode == "PT")
    }

    @Test func aPinAtSeaHasNoCountry() throws {
        let draft = ManualItemDraft(name: "Ferry bar", location: GeoPoint(longitude: -30, latitude: 30))
        #expect(draft.country == nil)
        let item = try repository.addManualItem(draft, in: collection(.restaurants))
        #expect(item.latitude == 30)
        #expect(item.countryCode == nil)
    }

    @Test func twoManualItemsWithTheSameNameStayApart() throws {
        let cafes = try collection(.cafes)
        let first = try repository.addManualItem(ManualItemDraft(name: "The kiosk"), in: cafes)
        let second = try repository.addManualItem(ManualItemDraft(name: "The kiosk"), in: cafes)
        #expect(first.id != second.id)
        let kiosks = cafes.items?.filter { $0.name == "The kiosk" } ?? []
        #expect(kiosks.count == 2)
    }

    @Test func loggingAManualPlaceStampsItsCountryLikeASearchedOne() throws {
        let cafes = try collection(.cafes)
        let kyoto = GeoPoint(longitude: 135.77, latitude: 35.01)
        let item = try repository.addManualItem(ManualItemDraft(name: "Tiny tea stall", location: kyoto), in: cafes)
        repository.addEntry(to: item)
        try repository.save()
        let countries = try collection(.countries).items ?? []
        #expect(countries.map(\.name) == ["Japan"])
    }
}
