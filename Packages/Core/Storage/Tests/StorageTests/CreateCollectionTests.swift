import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct CreateCollectionTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func draft(_ name: String) -> CollectionDraft {
        var draft = CollectionDraft()
        draft.name = name
        draft.icon = "music.note"
        draft.accentName = "film"
        draft.ratingMode = .ranked
        draft.defaultView = .grid
        draft.itemSource = .mapkit
        return draft
    }

    @Test func createsCustomCollectionWithChosenOptions() throws {
        let concerts = try repository.createCollection(from: draft("  Concerts "))
        #expect(concerts.name == "Concerts")
        #expect(concerts.kind == .custom)
        #expect(!concerts.isBuiltIn)
        #expect(concerts.icon == "music.note")
        #expect(concerts.accentName == "film")
        #expect(concerts.ratingMode == .ranked)
        #expect(concerts.defaultView == .grid)
        #expect(concerts.itemSource == .mapkit)
    }

    @Test func newCollectionGoesLast() throws {
        try repository.createCollection(from: draft("Hikes"))
        #expect(try repository.collections().last?.name == "Hikes")
    }

    @Test func emptyOrWhitespaceNameIsRejected() throws {
        #expect(throws: CollectionDraftError.invalid) {
            try repository.createCollection(from: draft("   "))
        }
        #expect(try repository.collections(includeHidden: true).count == 6)
    }

    @Test func overlongNameIsRejected() {
        #expect(!draft(String(repeating: "a", count: 41)).isValid)
        #expect(draft(String(repeating: "a", count: 40)).isValid)
    }

    @Test func catalogSourcesAreNotAllowedForCustomCollections() {
        var tmdb = draft("Series")
        tmdb.itemSource = .tmdb
        #expect(!tmdb.isValid)
    }
}
