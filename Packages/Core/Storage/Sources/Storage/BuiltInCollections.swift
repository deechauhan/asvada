import Foundation
import Model
import SwiftData

/// The six collections every user starts with, and the seeding that creates them.
///
/// Seeding is keyed by `CollectionKind`, not by a "first launch" flag: it only creates a
/// built-in whose kind doesn't exist yet (hidden ones included). That makes it safe to run on
/// every launch, after a restore, or after sync delivers collections from another device.
/// Built-ins are meant to be hidden, not deleted; a deleted one comes back on next launch.
public enum BuiltInCollections {
    public struct Spec: Sendable, Equatable {
        public let kind: CollectionKind
        public let name: String
        public let icon: String
        public let ratingMode: RatingMode
        public let defaultView: ViewMode
        public let itemSource: ItemSource
    }

    /// In display order.
    public static let all: [Spec] = [
        Spec(
            kind: .cafes,
            name: "Cafés",
            icon: "cup.and.saucer.fill",
            ratingMode: .ranked,
            defaultView: .ranked,
            itemSource: .mapkit,
        ),
        Spec(
            kind: .restaurants,
            name: "Restaurants",
            icon: "fork.knife",
            ratingMode: .ranked,
            defaultView: .ranked,
            itemSource: .mapkit,
        ),
        Spec(
            kind: .countries,
            name: "Countries",
            icon: "globe.europe.africa.fill",
            ratingMode: .checklist,
            defaultView: .progress,
            itemSource: .countryCatalog,
        ),
        Spec(
            kind: .cities,
            name: "Cities",
            icon: "building.2.fill",
            ratingMode: .checklist,
            defaultView: .map,
            itemSource: .mapkit,
        ),
        Spec(
            kind: .airlines,
            name: "Airlines",
            icon: "airplane",
            ratingMode: .log,
            defaultView: .list,
            itemSource: .airlineCatalog,
        ),
        Spec(
            kind: .films,
            name: "Films",
            icon: "film.fill",
            ratingMode: .log,
            defaultView: .grid,
            itemSource: .tmdb,
        ),
    ]

    /// Creates any missing built-in collections and saves. Returns how many were created.
    @MainActor
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext) throws -> Int {
        let existingKinds = try Set(context.fetch(FetchDescriptor<ExperienceCollection>()).map(\.kind))
        var created = 0
        for (index, spec) in all.enumerated() where !existingKinds.contains(spec.kind) {
            context.insert(ExperienceCollection(
                name: spec.name,
                icon: spec.icon,
                kind: spec.kind,
                ratingMode: spec.ratingMode,
                defaultView: spec.defaultView,
                itemSource: spec.itemSource,
                sortIndex: index,
            ))
            created += 1
        }
        if created > 0 {
            try context.save()
        }
        return created
    }
}

public extension ExperienceCollection {
    /// Built-in collections (everything except `.custom`) can be hidden but not deleted.
    var isBuiltIn: Bool {
        kind != .custom
    }
}
