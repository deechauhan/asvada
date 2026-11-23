import Foundation
import Model

/// What the user fills in to create or edit a collection.
public struct CollectionDraft: Equatable, Sendable {
    public var name: String = ""
    public var icon: String = "star.fill"
    /// Design-system accent name, e.g. "film".
    public var accentName: String = "custom"
    public var ratingMode: RatingMode = .stars
    public var defaultView: ViewMode = .list
    public var itemSource: ItemSource = .manual
    /// Built-ins keep their kind and item source; only custom collections choose a source.
    public private(set) var kind: CollectionKind = .custom

    /// Item sources a custom collection may use (catalogs and TMDB belong to built-ins).
    public static let customItemSources: [ItemSource] = [.manual, .mapkit]

    public init() {}

    /// A draft pre-filled from an existing collection, for editing.
    public init(editing collection: ExperienceCollection) {
        name = collection.name
        icon = collection.icon
        accentName = collection.accentName
        ratingMode = collection.ratingMode
        defaultView = collection.defaultView
        itemSource = collection.itemSource
        kind = collection.kind
    }

    public var isBuiltIn: Bool {
        kind != .custom
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 40 && (isBuiltIn || Self.customItemSources.contains(itemSource))
    }
}

public enum CollectionDraftError: Error, Equatable {
    case invalid
    /// Built-in collections are hidden, never deleted.
    case cannotDeleteBuiltIn
}

/// What deleting a collection would remove, shown before the user confirms.
public struct DeletionImpact: Equatable, Sendable {
    public let items: Int
    public let entries: Int

    /// "This deletes 3 items and 5 entries." / "This collection is empty."
    public var summary: String {
        if items == 0 {
            return "This collection is empty."
        }
        let itemText = items == 1 ? "1 item" : "\(items) items"
        let entryText = entries == 1 ? "1 entry" : "\(entries) entries"
        return "This deletes \(itemText) and \(entryText). This can't be undone."
    }
}

public extension Repository {
    /// Creates a custom collection from a draft, placed after every existing collection.
    @discardableResult
    func createCollection(from draft: CollectionDraft) throws -> ExperienceCollection {
        guard draft.isValid, !draft.isBuiltIn else { throw CollectionDraftError.invalid }
        let nextIndex = try (collections(includeHidden: true).map(\.sortIndex).max() ?? -1) + 1
        let collection = ExperienceCollection(
            name: draft.trimmedName,
            icon: draft.icon,
            kind: .custom,
            ratingMode: draft.ratingMode,
            defaultView: draft.defaultView,
            itemSource: draft.itemSource,
            sortIndex: nextIndex,
        )
        collection.accentName = draft.accentName
        context.insert(collection)
        try context.save()
        return collection
    }

    /// Applies an edited draft. A built-in keeps its kind and item source.
    func update(_ collection: ExperienceCollection, from draft: CollectionDraft) throws {
        guard draft.isValid else { throw CollectionDraftError.invalid }
        collection.name = draft.trimmedName
        collection.icon = draft.icon
        collection.accentName = draft.accentName
        collection.ratingMode = draft.ratingMode
        collection.defaultView = draft.defaultView
        if !collection.isBuiltIn {
            collection.itemSource = draft.itemSource
        }
        try context.save()
    }

    /// How many items and entries deleting this collection would remove.
    func deletionImpact(of collection: ExperienceCollection) -> DeletionImpact {
        let items = collection.items ?? []
        return DeletionImpact(items: items.count, entries: items.reduce(0) { $0 + ($1.entries?.count ?? 0) })
    }

    /// Deletes a custom collection and everything in it. Built-ins can only be hidden.
    func deleteCollection(_ collection: ExperienceCollection) throws {
        guard !collection.isBuiltIn else { throw CollectionDraftError.cannotDeleteBuiltIn }
        context.delete(collection)
        try context.save()
    }
}
