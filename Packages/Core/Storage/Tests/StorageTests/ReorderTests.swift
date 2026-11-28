import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct ReorderTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try ArtifactsStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func names() throws -> [String] {
        try repository.collections(includeHidden: true).map(\.name)
    }

    @Test func movesDown() throws {
        // Cafés → after Countries (SwiftUI destination is the index *before* removal).
        try repository.reorder(repository.collections(includeHidden: true), moving: [0], to: 3)
        try repository.save()
        #expect(try names() == ["Restaurants", "Countries", "Cafés", "Cities", "Airlines", "Films"])
    }

    @Test func movesUp() throws {
        try repository.reorder(repository.collections(includeHidden: true), moving: [5], to: 0)
        try repository.save()
        #expect(try names() == ["Films", "Cafés", "Restaurants", "Countries", "Cities", "Airlines"])
    }

    @Test func movesSeveral() throws {
        try repository.reorder(repository.collections(includeHidden: true), moving: [0, 2], to: 6)
        try repository.save()
        #expect(try names() == ["Restaurants", "Cities", "Airlines", "Films", "Cafés", "Countries"])
    }

    @Test func orderPersistsAcrossContexts() throws {
        try repository.reorder(repository.collections(includeHidden: true), moving: [4], to: 0)
        try repository.save()
        let fresh = Repository(context: ModelContext(container))
        #expect(try fresh.collections(includeHidden: true).first?.name == "Airlines")
    }

    @Test func hideAndUnhide() throws {
        let cities = try #require(try repository.collections().first { $0.kind == .cities })
        repository.setHidden(true, for: cities)
        try repository.save()
        #expect(try !repository.collections().contains { $0.kind == .cities })
        repository.setHidden(false, for: cities)
        try repository.save()
        #expect(try repository.collections().contains { $0.kind == .cities })
    }
}
