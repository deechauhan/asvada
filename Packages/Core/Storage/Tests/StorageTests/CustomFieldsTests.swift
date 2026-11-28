import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct CustomFieldsTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func airlines() throws -> ExperienceCollection {
        let match = try repository.collections().first { $0.kind == .airlines }
        return try #require(match)
    }

    @Test func aNewCollectionKeepsItsCleanedFields() throws {
        var draft = CollectionDraft()
        draft.name = "Concerts"
        draft.fields = [
            CollectionField(name: " Seat ", type: .text),
            CollectionField(name: "", type: .number),
            CollectionField(name: "Stage", type: .choice, choices: ["Main", "Side"]),
        ]
        let concerts = try repository.createCollection(from: draft)
        #expect(concerts.fields.map(\.name) == ["Seat", "Stage"])
        #expect(concerts.fields.last?.choices == ["Main", "Side"])
    }

    @Test func editingStartsFromTheCollectionsFieldsAndSavesChanges() throws {
        let flights = try airlines()
        flights.fields = [CollectionField(name: "Seat")]

        var draft = CollectionDraft(editing: flights)
        #expect(draft.fields.map(\.name) == ["Seat"])
        draft.fields.append(CollectionField(name: "Cabin", type: .choice, choices: ["Economy", "Business"]))
        try repository.update(flights, from: draft)
        #expect(flights.fields.map(\.name) == ["Seat", "Cabin"])

        // Removing every field stores none.
        draft.fields = []
        try repository.update(flights, from: draft)
        #expect(flights.fieldSchemaJSON == nil)
    }

    @Test func builtInDrawersCanHaveFieldsToo() throws {
        let flights = try airlines()
        var draft = CollectionDraft(editing: flights)
        draft.fields = [CollectionField(name: "Seat")]
        try repository.update(flights, from: draft)
        #expect(flights.kind == .airlines)
        #expect(flights.fields.count == 1)
    }

    @Test func valuesEnteredWhileSealingAreKeptOnTheEntry() throws {
        let flights = try airlines()
        let seat = CollectionField(name: "Seat")
        let business = CollectionField(name: "Business class", type: .yesNo)
        flights.fields = [seat, business]
        let airline = try repository.addManualItem(ManualItemDraft(name: "Air Test"), in: flights)

        let entry = try repository.savour(
            airline,
            Savouring(extra: [seat.id: .text("12F"), business.id: .yesNo(false)]),
        )
        #expect(entry.extraValues[seat.id] == .text("12F"))
        #expect(entry.extraValues[business.id] == .yesNo(false))
    }

    @Test func valuesEditedInTheDetailsAreSavedAndReadBack() throws {
        let flights = try airlines()
        let seat = CollectionField(name: "Seat")
        flights.fields = [seat]
        let airline = try repository.addManualItem(ManualItemDraft(name: "Air Test"), in: flights)
        let entry = try repository.savour(airline, Savouring())

        var details = EntryDetails(entry)
        #expect(details.extra.isEmpty)
        details.extra[seat.id] = .text("3A")
        try repository.update(entry, with: details)
        #expect(EntryDetails(entry).extra[seat.id] == .text("3A"))

        // Clearing it removes it.
        details.extra[seat.id] = .text("")
        try repository.update(entry, with: details)
        #expect(entry.extraJSON == nil)
    }

    @Test func aDeletedEntryComesBackWithItsValues() throws {
        let flights = try airlines()
        let seat = CollectionField(name: "Seat")
        flights.fields = [seat]
        let airline = try repository.addManualItem(ManualItemDraft(name: "Air Test"), in: flights)
        let entry = try repository.savour(airline, Savouring(extra: [seat.id: .text("9C")]))
        let deleted = try repository.deleteEntry(entry)
        let restored = try #require(try repository.restore(deleted))
        #expect(restored.extraValues[seat.id] == .text("9C"))
    }
}
