import Foundation
import Model
import SwiftData

extension BackupBundle {
    /// Restores a bundle's rows into `context` and saves. The bundle is checked first (see
    /// `verify`), so a damaged or too-new bundle changes nothing.
    ///
    /// A row whose id is already in the store is left as it is, so importing the same bundle twice
    /// adds nothing the second time. Choosing between two versions of a row is the merging restore's
    /// job (#58).
    @discardableResult
    public static func importFiles(_ files: [String: Data], into context: ModelContext) throws -> ImportSummary {
        let (_, data) = try verify(files)
        var restore = try Restore(context: context, files: files)
        // Rows first, then the links between them: SwiftData is fragile when objects are linked
        // before they are in a context.
        restore.addCollections(data.collections)
        let newItems = restore.addItems(data.items)
        restore.addTrips(data.trips)
        restore.addTags(data.tags)
        restore.addPeople(data.people)
        let newEntries = restore.addEntries(data.entries)
        let newPhotos = try restore.addPhotos(data.photos)
        restore.link(items: newItems, entries: newEntries, photos: newPhotos)
        try context.save()
        return restore.summary
    }

    /// The store being restored into: what it already holds, by id, and what has been added.
    private struct Restore {
        let context: ModelContext
        let files: [String: Data]
        var summary = ImportSummary()
        var collections: [UUID: ExperienceCollection]
        var items: [UUID: Item]
        var entries: [UUID: Entry]
        var trips: [UUID: Trip]
        var tags: [UUID: Tag]
        var people: [UUID: Person]
        var photoIDs: Set<UUID>

        init(context: ModelContext, files: [String: Data]) throws {
            self.context = context
            self.files = files
            collections = try Self.existing(ExperienceCollection.self, in: context, id: \.id)
            items = try Self.existing(Item.self, in: context, id: \.id)
            entries = try Self.existing(Entry.self, in: context, id: \.id)
            trips = try Self.existing(Trip.self, in: context, id: \.id)
            tags = try Self.existing(Tag.self, in: context, id: \.id)
            people = try Self.existing(Person.self, in: context, id: \.id)
            photoIDs = try Set(Self.existing(Photo.self, in: context, id: \.id).keys)
        }

        private static func existing<Row: PersistentModel>(
            _: Row.Type,
            in context: ModelContext,
            id: KeyPath<Row, UUID>,
        ) throws -> [UUID: Row] {
            var found: [UUID: Row] = [:]
            for row in try context.fetch(FetchDescriptor<Row>()) {
                found[row[keyPath: id]] = row
            }
            return found
        }

        /// The rows not already in the store.
        private static func fresh<Record>(
            _ rows: [Record],
            id: KeyPath<Record, UUID>,
            known: Set<UUID>,
            skipped: inout Int,
        ) -> [Record] {
            rows.filter { row in
                let isKnown = known.contains(row[keyPath: id])
                if isKnown {
                    skipped += 1
                }
                return !isKnown
            }
        }

        mutating func addCollections(_ rows: [CollectionRecord]) {
            let added = Self.fresh(rows, id: \.id, known: Set(collections.keys), skipped: &summary.skipped.collections)
            for row in added {
                let collection = ExperienceCollection(
                    name: row.name,
                    icon: row.icon,
                    kind: CollectionKind(rawValue: row.kind) ?? .custom,
                    ratingMode: RatingMode(rawValue: row.ratingMode) ?? .stars,
                    defaultView: ViewMode(rawValue: row.defaultView) ?? .list,
                    itemSource: ItemSource(rawValue: row.itemSource) ?? .manual,
                    sortIndex: row.sortIndex,
                )
                collection.id = row.id
                collection.accentName = row.accentName
                collection.fieldSchemaJSON = row.fieldSchemaJSON
                collection.isHidden = row.isHidden
                collection.createdAt = row.createdAt
                context.insert(collection)
                collections[row.id] = collection
            }
            summary.added.collections += added.count
        }

        mutating func addItems(_ rows: [ItemRecord]) -> [ItemRecord] {
            let added = Self.fresh(rows, id: \.id, known: Set(items.keys), skipped: &summary.skipped.items)
            for row in added {
                let item = Item(name: row.name, externalRef: row.externalRef)
                item.id = row.id
                item.latitude = row.latitude
                item.longitude = row.longitude
                item.countryCode = row.countryCode
                item.metadataJSON = row.metadataJSON
                item.rankScore = row.rankScore
                item.createdAt = row.createdAt
                context.insert(item)
                items[row.id] = item
            }
            summary.added.items += added.count
            return added
        }

        mutating func addTrips(_ rows: [TripRecord]) {
            let added = Self.fresh(rows, id: \.id, known: Set(trips.keys), skipped: &summary.skipped.trips)
            for row in added {
                let trip = Trip(name: row.name, start: row.start, end: row.end)
                trip.id = row.id
                context.insert(trip)
                trips[row.id] = trip
            }
            summary.added.trips += added.count
        }

        mutating func addTags(_ rows: [NamedRecord]) {
            let added = Self.fresh(rows, id: \.id, known: Set(tags.keys), skipped: &summary.skipped.tags)
            for row in added {
                let tag = Tag(name: row.name)
                tag.id = row.id
                context.insert(tag)
                tags[row.id] = tag
            }
            summary.added.tags += added.count
        }

        mutating func addPeople(_ rows: [NamedRecord]) {
            let added = Self.fresh(rows, id: \.id, known: Set(people.keys), skipped: &summary.skipped.people)
            for row in added {
                let person = Person(name: row.name)
                person.id = row.id
                context.insert(person)
                people[row.id] = person
            }
            summary.added.people += added.count
        }

        mutating func addEntries(_ rows: [EntryRecord]) -> [EntryRecord] {
            let added = Self.fresh(rows, id: \.id, known: Set(entries.keys), skipped: &summary.skipped.entries)
            for row in added {
                let entry = Entry(date: row.date, rating: row.rating, notes: row.notes)
                entry.id = row.id
                entry.extraJSON = row.extraJSON
                context.insert(entry)
                entries[row.id] = entry
            }
            summary.added.entries += added.count
            return added
        }

        mutating func addPhotos(_ rows: [PhotoRecord]) throws -> [(row: PhotoRecord, photo: Photo)] {
            let added = Self.fresh(rows, id: \.id, known: photoIDs, skipped: &summary.skipped.photos)
            var photos: [(row: PhotoRecord, photo: Photo)] = []
            for row in added {
                let photo = try Photo(
                    imageData: row.imageFile.map(contents),
                    thumbnailData: row.thumbnailFile.map(contents),
                    takenAt: row.takenAt,
                )
                photo.id = row.id
                photo.latitude = row.latitude
                photo.longitude = row.longitude
                context.insert(photo)
                photos.append((row, photo))
            }
            summary.added.photos += added.count
            return photos
        }

        /// A file's contents, or `missingFile`. (`verify` has already checked every file the
        /// manifest lists; this covers a photo record pointing somewhere else.)
        private func contents(of path: String) throws -> Data {
            guard let data = files[path] else { throw BackupError.missingFile(path) }
            return data
        }

        /// The links of the rows that were just added.
        func link(
            items newItems: [ItemRecord],
            entries newEntries: [EntryRecord],
            photos newPhotos: [(row: PhotoRecord, photo: Photo)],
        ) {
            for row in newItems {
                guard let item = items[row.id] else { continue }
                item.collection = row.collectionID.flatMap { collections[$0] }
            }
            for row in newEntries {
                guard let entry = entries[row.id] else { continue }
                entry.item = row.itemID.flatMap { items[$0] }
                entry.trip = row.tripID.flatMap { trips[$0] }
                entry.tags = row.tagIDs.compactMap { tags[$0] }
                entry.people = row.personIDs.compactMap { people[$0] }
            }
            for (row, photo) in newPhotos {
                photo.entry = row.entryID.flatMap { entries[$0] }
            }
        }
    }
}
