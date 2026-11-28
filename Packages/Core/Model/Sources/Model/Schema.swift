import SwiftData

/// Version 1 of the store schema: the models as first shipped.
///
/// Until the first TestFlight build there are no real stores, so V1 may still change in place.
/// From the first TestFlight build on, V1 is frozen and every change needs a new version.
///
/// How to change the schema later:
/// 1. Copy today's model classes into `SchemaV1` as nested types (freezing V1 exactly).
/// 2. Change the top-level models and add `SchemaV2` listing them.
/// 3. Append `SchemaV2` to `ArtifactsMigrationPlan.schemas` and a `MigrationStage` (lightweight
///    where possible) to `stages`; point `CurrentSchema` at `SchemaV2`.
/// 4. Add a test that a V1 store opens and migrates (see `SchemaMigrationTests`).
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        ModelModule.models
    }
}

/// The schema version this build writes.
public typealias CurrentSchema = SchemaV1

/// Every schema version the app has shipped, oldest first, and how to move between them.
public enum ArtifactsMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
