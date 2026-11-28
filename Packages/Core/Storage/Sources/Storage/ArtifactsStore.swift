import Foundation
import Model
import SwiftData

/// Creates the app's SwiftData container.
///
/// Local-only for now (`cloudKitDatabase: .none`): iCloud backup arrives in M3 and sync is an
/// explicit opt-in later, so the store must never start syncing just because an entitlement exists.
public enum ArtifactsStore {
    /// The current versioned schema (see `CurrentSchema` and `ArtifactsMigrationPlan` in Model).
    public static var schema: Schema {
        Schema(versionedSchema: CurrentSchema.self)
    }

    /// Where the store lives on disk.
    public enum Location: Sendable {
        /// The default location in the app's Application Support directory.
        case standard
        /// A specific file, e.g. for tests.
        case file(URL)
        /// Nothing is written to disk (previews, tests, UI tests).
        case inMemory
    }

    public static func makeContainer(_ location: Location = .standard) throws -> ModelContainer {
        let configuration = switch location {
        case .standard:
            ModelConfiguration("Artifacts", schema: schema, cloudKitDatabase: .none)
        case let .file(url):
            ModelConfiguration("Artifacts", schema: schema, url: url, cloudKitDatabase: .none)
        case .inMemory:
            ModelConfiguration("Artifacts", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: ArtifactsMigrationPlan.self, configurations: configuration)
    }
}
