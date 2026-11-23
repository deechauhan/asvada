import DesignSystem
import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct ItemKeepsakeTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
    }

    @Test func eachKindHasItsKeepsake() {
        let styles = CollectionKind.allCases.map(\.keepsakeStyle)
        #expect(styles == [.receipt, .menuCard, .passportStamp, .postcard, .boardingPass, .ticketStub, .luggageTag])
    }

    @Test func customCollectionsUseTheLuggageTag() {
        #expect(CollectionKind.custom.keepsakeStyle == .luggageTag)
    }

    @Test func airlinesKnowTheirIataCode() {
        #expect(Item(name: "British Airways", externalRef: "iata:ba").iataCode == "BA")
        #expect(Item(name: "Virgin Atlantic").iataCode == "VA")
    }

    @Test func dishesComeFromTheLatestNote() throws {
        let restaurants = ExperienceCollection(name: "Restaurants", icon: "fork.knife", kind: .restaurants)
        repository.context.insert(restaurants)
        let item = repository.upsertItem(named: "Dishoom", externalRef: nil, in: restaurants)
        repository.addEntry(to: item, date: .distantPast, notes: "Nothing")
        repository.addEntry(to: item, date: .now, notes: "House black daal, bacon naan roll;\nchai, okra fries")
        try repository.save()
        #expect(item.dishes == ["House black daal", "bacon naan roll", "chai"])
        #expect(item.encounterCount == 2)
    }

    @Test func anItemWithNoEntriesStillCountsOnce() {
        #expect(Item(name: "Kaffeine").encounterCount == 1)
    }
}
