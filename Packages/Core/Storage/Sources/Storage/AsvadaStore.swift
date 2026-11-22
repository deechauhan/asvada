import Foundation
import Model
import SwiftData

/// Creates the app's SwiftData container.
///
/// Local-only for now (`cloudKitDatabase: .none`): iCloud backup arrives in M3 and sync is an
/// explicit opt-in later, so the store must never start syncing just because an entitlement exists.
public enum AsvadaStore {
    public static var schema: Schema {
        Schema(ModelModule.models)
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
            ModelConfiguration("Asvada", schema: schema, cloudKitDatabase: .none)
        case let .file(url):
            ModelConfiguration("Asvada", schema: schema, url: url, cloudKitDatabase: .none)
        case .inMemory:
            ModelConfiguration("Asvada", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
