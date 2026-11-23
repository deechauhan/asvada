import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct OnboardingStoreTests {
    let container: ModelContainer
    let repository: Repository

    init() throws {
        container = try AsvadaStore.makeContainer(.inMemory)
        repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
    }

    private func items(_ kind: CollectionKind) throws -> [Item] {
        try repository.collections().first { $0.kind == kind }?.items ?? []
    }

    @Test func stampingAddsEachCountryOnceWithItsCode() throws {
        let first = try OnboardingStore.stamp(["JP", "PT"], in: repository)
        #expect(first == 2)
        // Stamping again (e.g. after going back) doesn't duplicate.
        let again = try OnboardingStore.stamp(["JP", "PT", "PE"], in: repository)
        #expect(again == 3)
        let countries = try items(.countries)
        #expect(Set(countries.compactMap(\.countryCode)) == ["JP", "PT", "PE"])
        #expect(countries.contains { $0.name == "Japan" && $0.externalRef == "iso:JP" })
    }

    @Test func unknownCodesAreIgnored() throws {
        let stamped = try OnboardingStore.stamp(["ZZ"], in: repository)
        #expect(stamped == 0)
    }

    @Test func savouringLogsTheFirstKeepsake() throws {
        let entry = try OnboardingStore.savour("  Prufrock  ", kind: .cafes, in: repository)
        #expect(entry?.item?.name == "Prufrock")
        let cafes = try items(.cafes)
        #expect(cafes.count == 1)
    }

    @Test func anEmptyNameSavoursNothing() throws {
        let entry = try OnboardingStore.savour("   ", kind: .films, in: repository)
        #expect(entry == nil)
    }
}
