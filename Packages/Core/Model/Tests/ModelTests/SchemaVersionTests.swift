import SwiftData
import Testing
@testable import Model

struct SchemaVersionTests {
    @Test func currentSchemaIsTheNewestInThePlan() throws {
        let newest = try #require(ArtifactsMigrationPlan.schemas.last)
        #expect(newest.versionIdentifier == CurrentSchema.versionIdentifier)
    }

    /// Note: a `\.versionIdentifier` key path on `any VersionedSchema.Type` crashes the Swift 6.3 compiler; use a closure.
    @Test func planVersionsIncreaseStrictly() {
        // swiftformat:disable:next preferKeyPath
        let versions = ArtifactsMigrationPlan.schemas.map { $0.versionIdentifier }
            .map { [$0.major, $0.minor, $0.patch] }
        for (older, newer) in zip(versions, versions.dropFirst()) {
            #expect(older.lexicographicallyPrecedes(newer), "\(older) is not before \(newer)")
        }
    }

    @Test func oneStagePerVersionStep() {
        #expect(ArtifactsMigrationPlan.stages.count == ArtifactsMigrationPlan.schemas.count - 1)
    }

    @Test func v1ContainsEveryModel() {
        #expect(Schema(versionedSchema: SchemaV1.self).entities.count == ModelModule.models.count)
    }
}
