import Foundation
import Geo
import Model

/// An item written in by hand, for when search can't find it: a name, and optionally where it is.
public struct ManualItemDraft: Sendable, Equatable {
    public var name: String
    /// Where it is, if the owner dropped a pin.
    public var location: GeoPoint?

    public init(name: String = "", location: GeoPoint? = nil) {
        self.name = name
        self.location = location
    }

    /// The name as it will be saved: trimmed of surrounding spaces and new lines.
    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A name is the only thing required.
    public var isValid: Bool {
        !trimmedName.isEmpty
    }

    /// The country the pin is in (or just off the coast of), if there is a pin and it's on land.
    public var country: Country? {
        location.flatMap { CountryCatalog.shared.country(at: $0) }
    }
}

public enum ManualItemError: Error, Equatable {
    case emptyName
}

public extension Repository {
    /// Adds an item written in by hand to `collection` and saves. It has no external reference,
    /// so two items with the same name stay two items. A pin gives it coordinates and the
    /// country they're in, just like a place found by search, so logging it stamps the country.
    @discardableResult
    func addManualItem(_ draft: ManualItemDraft, in collection: ExperienceCollection) throws -> Item {
        guard draft.isValid else { throw ManualItemError.emptyName }
        let item = upsertItem(named: draft.trimmedName, externalRef: nil, in: collection)
        if let location = draft.location {
            item.latitude = location.latitude
            item.longitude = location.longitude
            item.countryCode = draft.country?.code
        }
        try save()
        return item
    }
}
