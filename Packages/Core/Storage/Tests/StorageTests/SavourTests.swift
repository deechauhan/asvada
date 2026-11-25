import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct SavourTests {
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

    @Test func savouringAddsAnEntryWithItsRatingDateAndNote() throws {
        let films = try collection(.films)
        let film = try repository.addManualItem(ManualItemDraft(name: "Perfect Days"), in: films)
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let entry = try repository.savour(film, Savouring(date: day, rating: 4, note: "  quiet and lovely \n"))
        #expect(entry.item?.id == film.id)
        #expect(entry.date == day)
        #expect(entry.rating == 4)
        #expect(entry.notes == "quiet and lovely")
        #expect(film.entries?.count == 1)
    }

    @Test func aDuelPlacesTheItemInItsRanking() throws {
        let cafes = try collection(.cafes)
        let first = try repository.addManualItem(ManualItemDraft(name: "Prufrock"), in: cafes)
        let second = try repository.addManualItem(ManualItemDraft(name: "Monmouth"), in: cafes)
        try repository.savour(first, Savouring(rankPosition: 0))
        // The newcomer beat Prufrock: it goes to the top.
        try repository.savour(second, Savouring(rankPosition: 0))
        #expect(repository.ranking(of: cafes).map(\.name) == ["Monmouth", "Prufrock"])
    }

    @Test func aRepeatVisitKeepsItsPlace() throws {
        let cafes = try collection(.cafes)
        let first = try repository.addManualItem(ManualItemDraft(name: "Prufrock"), in: cafes)
        let second = try repository.addManualItem(ManualItemDraft(name: "Monmouth"), in: cafes)
        try repository.savour(first, Savouring(rankPosition: 0))
        try repository.savour(second, Savouring(rankPosition: 1))
        try repository.savour(first, Savouring())
        #expect(repository.ranking(of: cafes).map(\.name) == ["Prufrock", "Monmouth"])
        #expect(first.entries?.count == 2)
    }
}
