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
        container = try ArtifactsStore.makeContainer(.inMemory)
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
        // Relationships are unordered: compare as details (A to Z) and look people up by name.
        #expect(EntryDetails(first).people == ["Ana", "Ben"])
        // Typing "ana" found Ana, so the second entry shows her name as first spelled.
        #expect(EntryDetails(second).people == ["Ana"])
        // "ana" and "Birthday" reuse the person and tag already there.
        let ana = { (entry: Entry) in entry.people?.first { $0.name == "Ana" }?.id }
        let birthday = { (entry: Entry) in entry.tags?.first { $0.name == "birthday" }?.id }
        #expect(ana(second) != nil)
        #expect(ana(second) == ana(first))
        #expect(birthday(second) != nil)
        #expect(birthday(second) == birthday(first))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Model.Person>()) == 2)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Model.Tag>()) == 2)
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

    @Test func aRatingIsEditedInHalves() throws {
        let entry = try repository.savour(cafe("Prufrock"), Savouring(rating: 3))
        var details = EntryDetails(entry)
        #expect(details.rating == 3)
        details.rating = 4.5
        try repository.update(entry, with: details)
        #expect(repository.entry(id: entry.id)?.rating == 4.5)
    }
}
