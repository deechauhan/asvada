import Foundation
import Model

/// What the user fills in to create a custom collection.
public struct CollectionDraft: Equatable, Sendable {
    public var name: String = ""
    public var icon: String = "star.fill"
    /// Design-system accent name, e.g. "film".
    public var accentName: String = "custom"
    public var ratingMode: RatingMode = .stars
    public var defaultView: ViewMode = .list
    public var itemSource: ItemSource = .manual

    /// Item sources a custom collection may use (catalogs and TMDB belong to built-ins).
    public static let customItemSources: [ItemSource] = [.manual, .mapkit]

    public init() {}

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 40 && Self.customItemSources.contains(itemSource)
    }
}

public enum CollectionDraftError: Error, Equatable {
    case invalid
}

public extension Repository {
    /// Creates a custom collection from a draft, placed after every existing collection.
    @discardableResult
    func createCollection(from draft: CollectionDraft) throws -> ExperienceCollection {
        guard draft.isValid else { throw CollectionDraftError.invalid }
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
}
