import Foundation
import Model
import SwiftData

public extension Repository {
    /// Deletes everything the owner has saved (every entry, photo, item, trip, tag, person and
    /// collection, custom ones included) and brings back the empty built-in collections, so the
    /// app starts again as on first launch. Returns what was deleted. It can't be undone, so the
    /// screen that calls it asks twice and offers a backup first (#60).
    @discardableResult
    func eraseEverything() throws -> BackupBundle.Counts {
        let deleted = try BackupBundle.Counts(
            collections: context.fetchCount(FetchDescriptor<ExperienceCollection>()),
            items: context.fetchCount(FetchDescriptor<Item>()),
            entries: context.fetchCount(FetchDescriptor<Entry>()),
            photos: context.fetchCount(FetchDescriptor<Photo>()),
            trips: context.fetchCount(FetchDescriptor<Trip>()),
            tags: context.fetchCount(FetchDescriptor<Tag>()),
            people: context.fetchCount(FetchDescriptor<Person>()),
        )
        // Children first, so nothing is left pointing at a deleted parent.
        try deleteAll(of: Photo.self)
        try deleteAll(of: Entry.self)
        try deleteAll(of: Item.self)
        try deleteAll(of: Trip.self)
        try deleteAll(of: Tag.self)
        try deleteAll(of: Person.self)
        try deleteAll(of: ExperienceCollection.self)
        try context.save()
        try BuiltInCollections.seedIfNeeded(in: context)
        return deleted
    }

    private func deleteAll<Row: PersistentModel>(of _: Row.Type) throws {
        for row in try context.fetch(FetchDescriptor<Row>()) {
            context.delete(row)
        }
    }
}
