import Foundation
import SwiftData
import Testing
@testable import Model

@Test func moduleIsLinked() {
    #expect(ModelModule.name == "Model")
}

/// An in-memory container with every model, for tests.
@MainActor
func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: Schema(ModelModule.models), configurations: config)
    return container.mainContext
}
