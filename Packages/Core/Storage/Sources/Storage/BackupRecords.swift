import Foundation

/// The rows of `data.json` in a backup bundle (docs/BACKUP_FORMAT.md): one flat table per model,
/// linked by ids. Enum values are stored as their raw strings so a newer app's value an older app
/// doesn't know falls back to a default instead of failing the restore.
struct BackupData: Codable, Equatable {
    var collections: [CollectionRecord] = []
    var items: [ItemRecord] = []
    var entries: [EntryRecord] = []
    var photos: [PhotoRecord] = []
    var trips: [TripRecord] = []
    var tags: [NamedRecord] = []
    var people: [NamedRecord] = []
}

struct CollectionRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var accentName: String
    var kind: String
    var ratingMode: String
    var defaultView: String
    var itemSource: String
    var fieldSchemaJSON: Data?
    var sortIndex: Int
    var isHidden: Bool
    var createdAt: Date
}

struct ItemRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var externalRef: String?
    var latitude: Double?
    var longitude: Double?
    var countryCode: String?
    var metadataJSON: Data?
    var rankScore: Double?
    var createdAt: Date
    var collectionID: UUID?
}

struct EntryRecord: Codable, Equatable {
    var id: UUID
    var date: Date
    var rating: Double?
    var notes: String
    var extraJSON: Data?
    var itemID: UUID?
    var tripID: UUID?
    var tagIDs: [UUID]
    var personIDs: [UUID]
}

/// A photo's details; its pictures are separate files under `photos/`.
struct PhotoRecord: Codable, Equatable {
    var id: UUID
    var takenAt: Date?
    var latitude: Double?
    var longitude: Double?
    var entryID: UUID?
    /// Paths relative to the bundle, e.g. `photos/<id>.photo`; nil when the photo has no such copy.
    var imageFile: String?
    var thumbnailFile: String?
}

struct TripRecord: Codable, Equatable {
    var id: UUID
    var name: String
    var start: Date?
    var end: Date?
}

/// A tag or a person: an id and a name.
struct NamedRecord: Codable, Equatable {
    var id: UUID
    var name: String
}
