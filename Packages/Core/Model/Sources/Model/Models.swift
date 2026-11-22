import Foundation
import SwiftData

// CloudKit-compatible by design (see docs/ARCHITECTURE.md):
// every attribute is optional or has a default, every relationship is optional and has an
// inverse, and nothing is marked unique. Duplicates are handled in code via `externalRef`.
// `ModelSchemaTests` enforces these rules.

/// A category such as Cafés, Countries or Films. Named to avoid clashing with Swift's `Collection`.
@Model
public final class ExperienceCollection {
    public var id: UUID = UUID()
    public var name: String = ""
    public var icon: String = "star"
    public var kind: CollectionKind = CollectionKind.custom
    public var ratingMode: RatingMode = RatingMode.stars
    public var defaultView: ViewMode = ViewMode.list
    public var itemSource: ItemSource = ItemSource.manual
    /// Custom field definitions (JSON).
    public var fieldSchemaJSON: Data?
    public var sortIndex: Int = 0
    public var isHidden: Bool = false
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Item.collection)
    public var items: [Item]? = []

    public init(
        name: String = "",
        icon: String = "star",
        kind: CollectionKind = .custom,
        ratingMode: RatingMode = .stars,
        defaultView: ViewMode = .list,
        itemSource: ItemSource = .manual,
        sortIndex: Int = 0,
    ) {
        self.name = name
        self.icon = icon
        self.kind = kind
        self.ratingMode = ratingMode
        self.defaultView = defaultView
        self.itemSource = itemSource
        self.sortIndex = sortIndex
    }
}

/// The thing itself: a café, Japan, a film.
@Model
public final class Item {
    public var id: UUID = UUID()
    public var name: String = ""
    /// Stable identity from a source: "iso:JP", "iata:BA", "tmdb:12345", "mk:<id>".
    public var externalRef: String?
    public var latitude: Double?
    public var longitude: Double?
    public var countryCode: String?
    /// Source-specific details such as poster path, address or flag (JSON).
    public var metadataJSON: Data?
    /// Position in a ranked collection (gapped, e.g. 1000, 2000…).
    public var rankScore: Double?
    public var createdAt: Date = Date.now
    public var collection: ExperienceCollection?

    @Relationship(deleteRule: .cascade, inverse: \Entry.item)
    public var entries: [Entry]? = []

    public init(name: String = "", externalRef: String? = nil, collection: ExperienceCollection? = nil) {
        self.name = name
        self.externalRef = externalRef
        self.collection = collection
    }
}

/// One encounter with an item: a visit, a viewing, a flight.
@Model
public final class Entry {
    public var id: UUID = UUID()
    public var date: Date = Date.now
    /// Star rating or normalised score, depending on the collection's rating mode.
    public var rating: Double?
    public var notes: String = ""
    /// Values for the collection's custom fields (JSON).
    public var extraJSON: Data?
    public var item: Item?
    public var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Photo.entry)
    public var photos: [Photo]? = []

    @Relationship(inverse: \Tag.entries)
    public var tags: [Tag]? = []

    @Relationship(inverse: \Person.entries)
    public var people: [Person]? = []

    public init(date: Date = .now, rating: Double? = nil, notes: String = "", item: Item? = nil) {
        self.date = date
        self.rating = rating
        self.notes = notes
        self.item = item
    }
}

/// A downscaled photo stored in the app (not a Photos library reference).
@Model
public final class Photo {
    public var id: UUID = UUID()
    @Attribute(.externalStorage)
    public var imageData: Data?
    @Attribute(.externalStorage)
    public var thumbnailData: Data?
    public var takenAt: Date?
    public var latitude: Double?
    public var longitude: Double?
    public var entry: Entry?

    public init(imageData: Data? = nil, thumbnailData: Data? = nil, takenAt: Date? = nil, entry: Entry? = nil) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.takenAt = takenAt
        self.entry = entry
    }
}

/// An optional grouping of entries, e.g. a trip to Japan.
@Model
public final class Trip {
    public var id: UUID = UUID()
    public var name: String = ""
    public var start: Date?
    public var end: Date?

    @Relationship(inverse: \Entry.trip)
    public var entries: [Entry]? = []

    public init(name: String = "", start: Date? = nil, end: Date? = nil) {
        self.name = name
        self.start = start
        self.end = end
    }
}

/// A lightweight label.
@Model
public final class Tag {
    public var id: UUID = UUID()
    public var name: String = ""
    public var entries: [Entry]? = []

    public init(name: String = "") {
        self.name = name
    }
}

/// Someone you shared an experience with.
@Model
public final class Person {
    public var id: UUID = UUID()
    public var name: String = ""
    public var entries: [Entry]? = []

    public init(name: String = "") {
        self.name = name
    }
}
