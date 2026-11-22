import SwiftData
import Testing
@testable import Model

struct SchemaVersionTests {
    @Test func currentSchemaIsTheNewestInThePlan() throws {
        let newest = try #require(AsvadaMigrationPlan.schemas.last)
        #expect(newest.versionIdentifier == CurrentSchema.versionIdentifier)
    }

    @Test func planVersionsIncreaseStrictly() {
        let versions = AsvadaMigrationPlan.schemas.map(\.versionIdentifier)
            .map { [$0.major, $0.minor, $0.patch] }
        for (older, newer) in zip(versions, versions.dropFirst()) {
            #expect(older.lexicographicallyPrecedes(newer), "\(older) is not before \(newer)")
        }
    }

    @Test func oneStagePerVersionStep() {
        #expect(AsvadaMigrationPlan.stages.count == AsvadaMigrationPlan.schemas.count - 1)
    }

    @Test func v1ContainsEveryModel() {
        #expect(Schema(versionedSchema: SchemaV1.self).entities.count == ModelModule.models.count)
    }
}
