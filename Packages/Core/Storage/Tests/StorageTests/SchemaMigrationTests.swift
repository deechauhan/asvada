import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct SchemaMigrationTests {
    /// A store written with the plain V1 schema (no migration plan, as a V1 build would have
    /// created it) must open with the current build's container and keep its data.
    @Test func v1StoreOpensWithCurrentBuild() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Artifacts.store")

        do {
            let v1Schema = Schema(versionedSchema: SchemaV1.self)
            let config = ModelConfiguration("Artifacts", schema: v1Schema, url: url, cloudKitDatabase: .none)
            let v1Container = try ModelContainer(for: v1Schema, configurations: config)
            let films = ExperienceCollection(name: "Films", kind: .films, ratingMode: .log)
            let film = Item(name: "Perfect Days", externalRef: "tmdb:976893")
            v1Container.mainContext.insert(films)
            v1Container.mainContext.insert(film)
            film.collection = films
            try v1Container.mainContext.save()
        }

        let current = try ArtifactsStore.makeContainer(.file(url))
        let items = try current.mainContext.fetch(FetchDescriptor<Item>())
        #expect(items.map(\.name) == ["Perfect Days"])
        #expect(items.first?.collection?.kind == .films)
    }
}
