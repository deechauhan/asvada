import CryptoKit
import Foundation
import Model
import SwiftData

/// The versioned backup bundle (#56, docs/BACKUP_FORMAT.md): everything in the store as plain
/// files, so a backup can be read without the app and restored into a newer one.
///
/// A bundle is a set of files keyed by their path inside it:
/// - `manifest.json`: format and schema versions, when it was made, row counts and a SHA-256 for
///   every other file;
/// - `data.json`: every collection, item, entry, trip, tag, person and photo record;
/// - `photos/<id>.photo` and `photos/<id>.thumb`: each photo's pictures, as the store holds them.
///
/// Export is deterministic: the same store gives byte-identical `data.json` and photo files.
/// iCloud Drive backup (#57) and merging restore (#58) build on this.
public enum BackupBundle {
    /// The bundle format this build writes and the newest one it reads.
    public static let formatVersion = 1

    public static let manifestPath = "manifest.json"
    public static let dataPath = "data.json"

    /// How many rows of each kind a bundle holds.
    public struct Counts: Codable, Equatable, Sendable {
        public var collections = 0
        public var items = 0
        public var entries = 0
        public var photos = 0
        public var trips = 0
        public var tags = 0
        public var people = 0
    }

    /// `manifest.json`.
    public struct Manifest: Codable, Equatable, Sendable {
        public var formatVersion: Int
        /// The store schema the data was written from, e.g. "1.0.0".
        public var schemaVersion: String
        public var createdAt: Date
        public var counts: Counts
        /// SHA-256 (lowercase hex) of every other file in the bundle, by path.
        public var files: [String: String]
    }

    /// What a restore did.
    public struct ImportSummary: Equatable, Sendable {
        /// Rows added to the store.
        public var added = Counts()
        /// Rows already in the store (same id), which are left as they are.
        public var skipped = Counts()
    }

    public enum BackupError: Error, Equatable {
        /// The bundle was written by a newer format than this build reads.
        case unsupportedFormat(Int)
        case missingFile(String)
        /// A file's contents don't match the manifest's checksum for it.
        case checksumMismatch(String)
        /// The counts in the manifest don't match `data.json`.
        case countMismatch
        /// `manifest.json` or `data.json` isn't valid.
        case unreadable(String)
    }

    // MARK: - Export

    /// Every row in `context` as a bundle's files.
    public static func export(from context: ModelContext, at date: Date = .now) throws -> [String: Data] {
        var data = BackupData()
        var files: [String: Data] = [:]
        data.collections = try context.fetch(FetchDescriptor<ExperienceCollection>())
            .map(record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        data.items = try context.fetch(FetchDescriptor<Item>())
            .map(record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        data.entries = try context.fetch(FetchDescriptor<Entry>())
            .map(record)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        data.trips = try context.fetch(FetchDescriptor<Trip>())
            .map { TripRecord(id: $0.id, name: $0.name, start: $0.start, end: $0.end) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        data.tags = try context.fetch(FetchDescriptor<Tag>())
            .map { NamedRecord(id: $0.id, name: $0.name) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        data.people = try context.fetch(FetchDescriptor<Person>())
            .map { NamedRecord(id: $0.id, name: $0.name) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        for photo in try context.fetch(FetchDescriptor<Photo>()).sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            var row = PhotoRecord(
                id: photo.id,
                takenAt: photo.takenAt,
                latitude: photo.latitude,
                longitude: photo.longitude,
                entryID: photo.entry?.id,
            )
            if let image = photo.imageData {
                let path = "photos/\(photo.id.uuidString).photo"
                row.imageFile = path
                files[path] = image
            }
            if let thumbnail = photo.thumbnailData {
                let path = "photos/\(photo.id.uuidString).thumb"
                row.thumbnailFile = path
                files[path] = thumbnail
            }
            data.photos.append(row)
        }

        files[dataPath] = try encoder(pretty: false).encode(data)
        let manifest = Manifest(
            formatVersion: formatVersion,
            schemaVersion: schemaVersionString,
            createdAt: date,
            counts: counts(of: data),
            files: files.mapValues(checksum),
        )
        files[manifestPath] = try encoder(pretty: true).encode(manifest)
        return files
    }

    // MARK: - Reading a bundle's files

    /// Checks a bundle and returns its manifest and rows: the format is one this build reads, every
    /// file the manifest lists is there and unchanged, and the counts add up.
    static func verify(_ files: [String: Data]) throws -> (manifest: Manifest, data: BackupData) {
        guard let manifestData = files[manifestPath] else { throw BackupError.missingFile(manifestPath) }
        let manifest: Manifest
        do {
            manifest = try decoder().decode(Manifest.self, from: manifestData)
        } catch {
            throw BackupError.unreadable(manifestPath)
        }
        guard manifest.formatVersion <= formatVersion else {
            throw BackupError.unsupportedFormat(manifest.formatVersion)
        }
        for (path, expected) in manifest.files.sorted(by: { $0.key < $1.key }) {
            guard let contents = files[path] else { throw BackupError.missingFile(path) }
            guard checksum(contents) == expected else { throw BackupError.checksumMismatch(path) }
        }
        guard let rows = files[dataPath], manifest.files[dataPath] != nil else {
            throw BackupError.missingFile(dataPath)
        }
        let data: BackupData
        do {
            data = try decoder().decode(BackupData.self, from: rows)
        } catch {
            throw BackupError.unreadable(dataPath)
        }
        guard counts(of: data) == manifest.counts else { throw BackupError.countMismatch }
        return (manifest, data)
    }

    // MARK: - Files on disk

    /// Writes a bundle's files under `directory`, creating folders as needed.
    public static func write(_ files: [String: Data], to directory: URL) throws {
        let manager = FileManager.default
        for (path, contents) in files {
            let url = directory.appending(path: path)
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, options: .atomic)
        }
    }

    /// Reads every file of a bundle under `directory`, keyed by path.
    public static func read(from directory: URL) throws -> [String: Data] {
        let manager = FileManager.default
        guard let walker = manager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw BackupError.missingFile(manifestPath)
        }
        let root = directory.standardizedFileURL.path
        var files: [String: Data] = [:]
        for case let url as URL in walker {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let path = String(url.standardizedFileURL.path.dropFirst(root.count + 1))
            files[path] = try Data(contentsOf: url)
        }
        return files
    }

    // MARK: - Helpers

    static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static var schemaVersionString: String {
        let version = CurrentSchema.versionIdentifier
        return "\(version.major).\(version.minor).\(version.patch)"
    }

    static func counts(of data: BackupData) -> Counts {
        Counts(
            collections: data.collections.count,
            items: data.items.count,
            entries: data.entries.count,
            photos: data.photos.count,
            trips: data.trips.count,
            tags: data.tags.count,
            people: data.people.count,
        )
    }

    /// Sorted keys keep the output the same every time. Dates are the Apple reference-date number of
    /// seconds, which keeps every bit of the `Date`.
    private static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    private static func record(_ collection: ExperienceCollection) -> CollectionRecord {
        CollectionRecord(
            id: collection.id,
            name: collection.name,
            icon: collection.icon,
            accentName: collection.accentName,
            kind: collection.kind.rawValue,
            ratingMode: collection.ratingMode.rawValue,
            defaultView: collection.defaultView.rawValue,
            itemSource: collection.itemSource.rawValue,
            fieldSchemaJSON: collection.fieldSchemaJSON,
            sortIndex: collection.sortIndex,
            isHidden: collection.isHidden,
            createdAt: collection.createdAt,
        )
    }

    private static func record(_ item: Item) -> ItemRecord {
        ItemRecord(
            id: item.id,
            name: item.name,
            externalRef: item.externalRef,
            latitude: item.latitude,
            longitude: item.longitude,
            countryCode: item.countryCode,
            metadataJSON: item.metadataJSON,
            rankScore: item.rankScore,
            createdAt: item.createdAt,
            collectionID: item.collection?.id,
        )
    }

    private static func record(_ entry: Entry) -> EntryRecord {
        EntryRecord(
            id: entry.id,
            date: entry.date,
            rating: entry.rating,
            notes: entry.notes,
            extraJSON: entry.extraJSON,
            itemID: entry.item?.id,
            tripID: entry.trip?.id,
            tagIDs: (entry.tags ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString },
            personIDs: (entry.people ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString },
        )
    }
}
