import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct GlobalSearchTests {
    /// An in-memory store with the built-ins. Hold on to it for the whole test: the context stops
    /// working once its container is released.
    private struct Store {
        let container: ModelContainer
        let repository: Repository
        let cafes: ExperienceCollection
        let films: ExperienceCollection
    }

    private func seededStore() throws -> Store {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        let collections = try repository.collections()
        let cafes = try #require(collections.first { $0.kind == .cafes })
        let films = try #require(collections.first { $0.kind == .films })
        return Store(container: container, repository: repository, cafes: cafes, films: films)
    }

    private func items(_ store: Store) -> [Item] {
        (store.cafes.items ?? []) + (store.films.items ?? [])
    }

    @Test func aBlankQueryFindsNothing() throws {
        let store = try seededStore()
        _ = store.repository.upsertItem(named: "Monmouth Coffee", externalRef: nil, in: store.cafes)
        #expect(GlobalSearch.groups(for: "", in: items(store)).isEmpty)
        #expect(GlobalSearch.groups(for: "   ", in: items(store)).isEmpty)
    }

    @Test func itemsAreFoundByNameIgnoringCaseAndAccents() throws {
        let store = try seededStore()
        _ = store.repository.upsertItem(named: "Café Kitsuné", externalRef: nil, in: store.cafes)
        _ = store.repository.upsertItem(named: "Prufrock", externalRef: nil, in: store.cafes)
        let groups = GlobalSearch.groups(for: "kitsune", in: items(store))
        #expect(groups.count == 1)
        #expect(groups.first?.hits.map(\.item.name) == ["Café Kitsuné"])
        #expect(groups.first?.hits.first?.match == SearchMatch.name)
    }

    @Test func resultsAreGroupedByCollectionInTheCabinetsOrder() throws {
        let store = try seededStore()
        _ = store.repository.upsertItem(named: "Perfect Days", externalRef: nil, in: store.films)
        _ = store.repository.upsertItem(named: "Perfect Day Coffee", externalRef: nil, in: store.cafes)
        let groups = GlobalSearch.groups(for: "perfect day", in: items(store))
        let order = [store.cafes, store.films].sorted { $0.sortIndex < $1.sortIndex }.map(\.id)
        #expect(groups.map(\.collection.id) == order)
        #expect(groups.allSatisfy { $0.hits.count == 1 })
    }

    @Test func notesPeopleAndTagsFindTheirItem() throws {
        let store = try seededStore()
        let context = store.repository.context
        let monmouth = store.repository.upsertItem(named: "Monmouth Coffee", externalRef: nil, in: store.cafes)
        let noted = store.repository.addEntry(to: monmouth, notes: "Best flat white after the rain\nsecond line")
        let ana = Person(name: "Ana")
        let rainy = Tag(name: "rainy day")
        context.insert(ana)
        context.insert(rainy)
        noted.people = [ana]
        noted.tags = [rainy]
        let all = items(store)

        #expect(GlobalSearch.groups(for: "ana", in: all).first?.hits.first?.match == SearchMatch.person("Ana"))
        #expect(GlobalSearch.groups(for: "RAINY", in: all).first?.hits.first?.match == SearchMatch.tag("rainy day"))
        #expect(GlobalSearch.groups(for: "flat white", in: all).first?.hits.first?.match
            == SearchMatch.note("Best flat white after the rain"))
        #expect(GlobalSearch.groups(for: "second line", in: all).isEmpty == false)
        #expect(GlobalSearch.groups(for: "espresso", in: all).isEmpty)
    }

    @Test func aNameMatchOutranksANoteMatchInTheSameDrawer() throws {
        let store = try seededStore()
        let quiet = store.repository.upsertItem(named: "Annie's", externalRef: nil, in: store.cafes)
        _ = store.repository.addEntry(to: quiet, notes: "with a view of the park")
        _ = store.repository.upsertItem(named: "Park Café", externalRef: nil, in: store.cafes)
        let hits = try #require(GlobalSearch.groups(for: "park", in: items(store)).first).hits
        #expect(hits.map(\.item.name) == ["Park Café", "Annie's"])
        #expect(hits.map(\.match) == [SearchMatch.name, SearchMatch.note("with a view of the park")])
    }

    @Test func drawersPutAwayStayOutOfTheResults() throws {
        let store = try seededStore()
        _ = store.repository.upsertItem(named: "Monmouth Coffee", externalRef: nil, in: store.cafes)
        store.repository.setHidden(true, for: store.cafes)
        #expect(GlobalSearch.groups(for: "monmouth", in: items(store)).isEmpty)
    }

    @Test func longNotesAreCutToTheirFirstLine() {
        let long = String(repeating: "a", count: 200)
        let snippet = GlobalSearch.snippet(of: "  \(long)  \nnext")
        #expect(snippet.hasSuffix("…"))
        #expect(snippet.count == GlobalSearch.snippetLength + 1)
        #expect(GlobalSearch.snippet(of: "short") == "short")
    }

    @Test func rowsSayWhatMatched() {
        #expect(SearchMatch.name.caption == nil as String?)
        #expect(SearchMatch.person("Ana").caption == "with Ana")
        #expect(SearchMatch.tag("rainy day").caption == "#rainy day")
        #expect(SearchMatch.note("lovely").caption == "“lovely”")
    }
}
