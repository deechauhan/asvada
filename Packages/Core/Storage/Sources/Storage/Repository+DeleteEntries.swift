import Foundation
import Model
import SwiftData

/// Everything a deleted entry held, so "Undo" can put it back exactly as it was: the same id,
/// item, trip, date, rating, note, people, tags and photos.
public struct DeletedEntry: Sendable, Equatable, Identifiable {
    /// One of its photos, kept whole until the undo window closes.
    public struct KeptPhoto: Sendable, Equatable {
        public let id: UUID
        public let imageData: Data?
        public let thumbnailData: Data?
        public let takenAt: Date?
        public let latitude: Double?
        public let longitude: Double?
    }

    public let id: UUID
    public let itemID: UUID?
    /// The item's name, for "Deleted your visit to Prufrock".
    public let itemName: String
    public let tripID: UUID?
    public let date: Date
    public let rating: Double?
    public let notes: String
    public let extraJSON: Data?
    public let people: [String]
    public let tags: [String]
    public let photos: [KeptPhoto]

    init(_ entry: Entry) {
        id = entry.id
        itemID = entry.item?.id
        itemName = entry.item?.name ?? ""
        tripID = entry.trip?.id
        date = entry.date
        rating = entry.rating
        notes = entry.notes
        extraJSON = entry.extraJSON
        let details = EntryDetails(entry)
        people = details.people
        tags = details.tags
        photos = (entry.photos ?? []).map { photo in
            KeptPhoto(
                id: photo.id,
                imageData: photo.imageData,
                thumbnailData: photo.thumbnailData,
                takenAt: photo.takenAt,
                latitude: photo.latitude,
                longitude: photo.longitude,
            )
        }
    }
}

public extension Repository {
    /// Deletes `entry` and its photos, and returns what it held for `restore(_:)`. The item stays
    /// (and keeps its place in a ranking) even when this was its only entry, and so does any
    /// country it stamped.
    @discardableResult
    func deleteEntry(_ entry: Entry) throws -> DeletedEntry {
        let deleted = DeletedEntry(entry)
        for photo in entry.photos ?? [] {
            remove(photo)
        }
        entry.item = nil
        entry.trip = nil
        entry.tags = []
        entry.people = []
        context.delete(entry)
        try save()
        return deleted
    }

    /// Puts a deleted entry back as it was. Returns nil if its item has since gone too.
    @discardableResult
    func restore(_ deleted: DeletedEntry) throws -> Entry? {
        guard let itemID = deleted.itemID, let item = storedItem(id: itemID) else { return nil }
        let entry = Entry(date: deleted.date, rating: deleted.rating, notes: deleted.notes)
        entry.id = deleted.id
        entry.extraJSON = deleted.extraJSON
        context.insert(entry)
        entry.item = item
        if let tripID = deleted.tripID {
            entry.trip = storedTrip(id: tripID)
        }
        setPeople(deleted.people, on: entry)
        setTags(deleted.tags, on: entry)
        for kept in deleted.photos {
            let photo = Photo(imageData: kept.imageData, thumbnailData: kept.thumbnailData, takenAt: kept.takenAt)
            photo.id = kept.id
            photo.latitude = kept.latitude
            photo.longitude = kept.longitude
            context.insert(photo)
            photo.entry = entry
        }
        try save()
        return entry
    }

    private func storedItem(id: UUID) -> Item? {
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func storedTrip(id: UUID) -> Trip? {
        var descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
