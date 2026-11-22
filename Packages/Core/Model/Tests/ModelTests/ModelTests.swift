import Foundation
import SwiftData
import Testing
@testable import Model

@Test func moduleIsLinked() {
    #expect(ModelModule.name == "Model")
}

/// An in-memory container with every model, for tests. Keep the container alive for the
/// whole test: a `ModelContext` doesn't retain its container.
func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return try ModelContainer(for: Schema(ModelModule.models), configurations: config)
}
