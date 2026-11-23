import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct ShareContentTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
    }

    private func content(for kind: CollectionKind) throws -> ShareContent? {
        let match = try repository.collections().first { $0.kind == kind }
        let collection = try #require(match)
        return ShareContent(collection: collection)
    }

    @Test func rankedCollectionsShareTheirTopFiveAsAMenu() throws {
        guard case let .topMenu(name, courses) = try content(for: .cafes) else {
            Issue.record("Cafés should share a top menu")
            return
        }
        #expect(name == "Cafés")
        #expect(courses.map(\.name) == ["Prufrock Coffee", "Monmouth", "Kaffeine", "Workshop"])
    }

    @Test func countriesShareThePassportInStampOrder() throws {
        guard case let .passport(stamps) = try content(for: .countries) else {
            Issue.record("Countries should share the passport spread")
            return
        }
        // Oldest stamp first: Kenya, Peru, Japan, Portugal.
        #expect(stamps.map(\.code) == ["KE", "PE", "JP", "PT"])
    }

    @Test func otherCollectionsShareTheirBestKeepsake() throws {
        guard case let .keepsake(item) = try content(for: .films) else {
            Issue.record("Films should share a keepsake")
            return
        }
        #expect(item.name == "Perfect Days")
    }

    @Test func emptyCollectionsHaveNothingToShare() throws {
        let restaurants = try content(for: .restaurants)
        #expect(restaurants == nil)
    }
}
