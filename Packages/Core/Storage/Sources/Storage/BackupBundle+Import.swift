import Foundation
import Model
import SwiftData

public extension BackupBundle {
    /// What restoring a bundle would do, worked out without changing the store.
    struct Preview: Equatable, Sendable {
        public var manifest: Manifest
        /// Rows that would be added (`added`) and rows already in the store (`skipped`).
        public var summary: ImportSummary
    }

    /// Checks a bundle and says what restoring it into `context` would add and what is already
    /// there, so the owner can see the counts before agreeing. Changes nothing.
    static func preview(_ files: [String: Data], in context: ModelContext) throws -> Preview {
        let (manifest, data) = try verify(files)
        let restore = try Restore(context: context, files: files)
        return Preview(manifest: manifest, summary: restore.tally(data))
    }

    /// Restores a bundle's rows into `context` and saves. The bundle is checked first (see
    /// `verify`), so a damaged or too-new bundle changes nothing.
    ///
    /// A row whose id is already in the store is left as it is, so importing the same bundle twice
    /// adds nothing the second time. Choosing between two versions of a row is the merging restore's
    /// job (#58).
    @discardableResult
    static func importFiles(_ files: [String: Data], into context: ModelContext) throws -> ImportSummary {
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
}

extension BackupBundle {
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

        /// How many of a bundle's rows are new and how many are already in the store.
        func tally(_ data: BackupData) -> ImportSummary {
            func split(_ ids: [UUID], known: Set<UUID>) -> (added: Int, skipped: Int) {
                let skipped = ids.filter { known.contains($0) }.count
                return (ids.count - skipped, skipped)
            }
            let counts = [
                split(data.collections.map(\.id), known: Set(collections.keys)),
                split(data.items.map(\.id), known: Set(items.keys)),
                split(data.entries.map(\.id), known: Set(entries.keys)),
                split(data.photos.map(\.id), known: photoIDs),
                split(data.trips.map(\.id), known: Set(trips.keys)),
                split(data.tags.map(\.id), known: Set(tags.keys)),
                split(data.people.map(\.id), known: Set(people.keys)),
            ]
            return ImportSummary(
                added: Counts(
                    collections: counts[0].added,
                    items: counts[1].added,
                    entries: counts[2].added,
                    photos: counts[3].added,
                    trips: counts[4].added,
                    tags: counts[5].added,
                    people: counts[6].added,
                ),
                skipped: Counts(
                    collections: counts[0].skipped,
                    items: counts[1].skipped,
                    entries: counts[2].skipped,
                    photos: counts[3].skipped,
                    trips: counts[4].skipped,
                    tags: counts[5].skipped,
                    people: counts[6].skipped,
                ),
            )
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
