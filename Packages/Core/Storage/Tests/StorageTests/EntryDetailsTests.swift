import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct EntryDetailsTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func cafe(_ name: String) throws -> Item {
        let cafes = try #require(try repository.collections().first { $0.kind == .cafes })
        return try repository.addManualItem(ManualItemDraft(name: name), in: cafes)
    }

    @Test func namesAreTrimmedAndNeverRepeated() {
        #expect(DetailNames.cleaned([" Ana ", "ana", "", "Ánà", "Ben"]) == ["Ana", "Ben"])
    }

    @Test func suggestionsStartWithWhatYouTypedAndSkipChosenOnes() {
        let known = ["Ana", "Andrés", "Ben", "anniversary"]
        #expect(DetailNames.suggestions(known, prefix: "an", excluding: []) == ["Ana", "Andrés", "anniversary"])
        #expect(DetailNames.suggestions(known, prefix: "AN", excluding: ["ana"]) == ["Andrés", "anniversary"])
        #expect(DetailNames.suggestions(known, prefix: "", excluding: [], limit: 2) == ["Ana", "Andrés"])
    }

    @Test func savouringWithPeopleAndTagsStoresEachNameOnce() throws {
        let first = try repository.savour(cafe("Prufrock"), Savouring(people: ["Ana", "Ben"], tags: ["birthday"]))
        let second = try repository.savour(cafe("Monmouth"), Savouring(people: ["ana"], tags: ["Birthday", "rainy"]))
        #expect((first.people ?? []).map(\.name) == ["Ana", "Ben"])
        // "ana" and "Birthday" reuse the people and tags already there.
        #expect(second.people?.first?.id == first.people?.first?.id)
        #expect(second.tags?.first?.id == first.tags?.first?.id)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Person>()) == 2)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Tag>()) == 2)
    }

    @Test func theMostUsedNamesComeFirst() throws {
        try repository.savour(cafe("A"), Savouring(people: ["Ben"], tags: ["rainy"]))
        try repository.savour(cafe("B"), Savouring(people: ["Ana", "Ben"], tags: ["rainy", "work"]))
        #expect(repository.peopleNames() == ["Ben", "Ana"])
        #expect(repository.tagNames() == ["rainy", "work"])
    }

    @Test func editsSaveOntoTheEntry() throws {
        let entry = try repository.savour(cafe("Prufrock"), Savouring(note: "first"))
        let lastYear = Date(timeIntervalSince1970: 1_760_000_000)
        try repository.update(
            entry,
            with: EntryDetails(date: lastYear, notes: " better second time ", people: ["Ana"], tags: ["weekend"]),
        )
        let found = try #require(repository.entry(id: entry.id))
        #expect(found.date == lastYear)
        #expect(found.notes == "better second time")
        #expect(EntryDetails(found) == EntryDetails(
            date: lastYear,
            notes: "better second time",
            people: ["Ana"],
            tags: ["weekend"],
        ))
    }
}
