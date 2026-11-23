import Foundation
import Model
import SwiftData

/// The small data API features use instead of talking to `ModelContext` directly.
///
/// Items are deduplicated by `externalRef` *within a collection*: logging Japan twice in
/// Countries updates one item, while "tmdb:129" can still exist in two different collections.
@MainActor
public struct Repository {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetch

    /// All collections in display order, optionally including hidden ones.
    public func collections(includeHidden: Bool = false) throws -> [ExperienceCollection] {
        let descriptor = FetchDescriptor<ExperienceCollection>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)])
        let all = try context.fetch(descriptor)
        return includeHidden ? all : all.filter { !$0.isHidden }
    }

    /// Items in a collection, alphabetically.
    public func items(in collection: ExperienceCollection) -> [Item] {
        (collection.items ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The item in `collection` with this external reference, if any.
    public func item(withExternalRef externalRef: String, in collection: ExperienceCollection) -> Item? {
        collection.items?.first { $0.externalRef == externalRef }
    }

    /// Entries newest first, across every collection.
    public func recentEntries(limit: Int? = nil) throws -> [Entry] {
        var descriptor = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    // MARK: - Write

    /// Inserts an item, or updates and returns the existing one with the same `externalRef` in
    /// the same collection. Items without an `externalRef` (manual entries) are always new.
    @discardableResult
    public func upsertItem(named name: String, externalRef: String?, in collection: ExperienceCollection) -> Item {
        if let externalRef, let existing = item(withExternalRef: externalRef, in: collection) {
            existing.name = name
            return existing
        }
        let item = Item(name: name, externalRef: externalRef)
        context.insert(item)
        item.collection = collection
        return item
    }

    /// Adds an entry (one encounter) for an item. If the item is a place with coordinates, its
    /// country is stamped in Countries too (see `stampCountry(of:on:)`).
    @discardableResult
    public func addEntry(to item: Item, date: Date = .now, rating: Double? = nil, notes: String = "") -> Entry {
        let entry = Entry(date: date, rating: rating, notes: notes)
        context.insert(entry)
        entry.item = item
        stampCountry(of: item, on: date)
        return entry
    }

    /// Moves collections within `ordered` (the list as the user sees it) and renumbers
    /// `sortIndex` to match, mirroring SwiftUI's `onMove(fromOffsets:toOffset:)`.
    public func reorder(_ ordered: [ExperienceCollection], moving source: IndexSet, to destination: Int) {
        var list = ordered
        let moving = source.map { list[$0] }
        let insertAt = destination - source.count(in: 0 ..< destination)
        for index in source.reversed() {
            list.remove(at: index)
        }
        list.insert(contentsOf: moving, at: insertAt)
        for (index, collection) in list.enumerated() {
            collection.sortIndex = index
        }
    }

    /// Hides or shows a collection (built-ins are hidden rather than deleted).
    public func setHidden(_ hidden: Bool, for collection: ExperienceCollection) {
        collection.isHidden = hidden
    }

    /// Deletes a model. Collections cascade to their items, entries and photos.
    public func delete(_ model: some PersistentModel) {
        context.delete(model)
    }

    public func save() throws {
        try context.save()
    }
}
