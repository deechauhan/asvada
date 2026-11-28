import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@Test func moduleIsLinked() {
    #expect(StorageModule.name == "Storage")
}

@MainActor
struct ArtifactsStoreTests {
    @Test func dataPersistsAcrossContainerRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Artifacts.store")

        do {
            let container = try ArtifactsStore.makeContainer(.file(url))
            let countries = ExperienceCollection(name: "Countries", kind: .countries, ratingMode: .checklist)
            let japan = Item(name: "Japan", externalRef: "iso:JP")
            container.mainContext.insert(countries)
            container.mainContext.insert(japan)
            japan.collection = countries
            try container.mainContext.save()
        }

        let reopened = try ArtifactsStore.makeContainer(.file(url))
        let items = try reopened.mainContext.fetch(FetchDescriptor<Item>())
        #expect(items.map(\.externalRef) == ["iso:JP"])
        #expect(items.first?.collection?.name == "Countries")
    }

    @Test func inMemoryStoreStartsEmpty() throws {
        let container = try ArtifactsStore.makeContainer(.inMemory)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ExperienceCollection>()) == 0)
    }

    @Test func schemaContainsEveryModel() {
        #expect(ArtifactsStore.schema.entities.count == ModelModule.models.count)
    }
}
