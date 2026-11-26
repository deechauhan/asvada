import Foundation
import Model
import SwiftData
import Testing
@testable import Storage

@MainActor
struct BackupBundleTests {
    /// A store with the built-ins, sample keepsakes, and one entry carrying everything an entry can:
    /// a photo, a tag, a person, a trip and custom-field values. Hold on to the container for the
    /// whole test: the context stops working once it's released.
    private func populatedStore() throws -> ModelContainer {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
        let films = try #require(try repository.collections().first { $0.kind == .films })
        films.fieldSchemaJSON = Data(#"[{"name":"Seat","type":"text"}]"#.utf8)
        films.accentName = "film"
        let film = try #require(repository.items(in: films).first)
        film.metadataJSON = Data(#"{"poster":"/p.jpg"}"#.utf8)
        film.latitude = 35.6762
        film.longitude = 139.6503
        let entry = repository.addEntry(
            to: film,
            date: Date(timeIntervalSinceReferenceDate: 786_000_000.123_456),
            rating: 4.5,
            notes: "Rainy Tuesday",
        )
        entry.extraJSON = Data(#"{"Seat":"F12"}"#.utf8)
        let context = repository.context
        let trip = Trip(name: "Japan", start: .now, end: .now.addingTimeInterval(86400))
        let tag = Tag(name: "rainy day")
        let person = Person(name: "Ana")
        let photo = Photo(imageData: Data([1, 2, 3, 4]), thumbnailData: Data([9, 8]), takenAt: .now)
        photo.latitude = 35.0
        photo.longitude = 139.0
        for model in [trip, tag, person, photo] as [any PersistentModel] {
            context.insert(model)
        }
        entry.trip = trip
        entry.tags = [tag]
        entry.people = [person]
        photo.entry = entry
        try context.save()
        return container
    }

    private func manifest(of files: [String: Data]) throws -> BackupBundle.Manifest {
        let decoder = JSONDecoder()
        return try decoder.decode(BackupBundle.Manifest.self, from: #require(files[BackupBundle.manifestPath]))
    }

    private func rewrite(_ manifest: BackupBundle.Manifest, in files: [String: Data]) throws -> [String: Data] {
        var files = files
        files[BackupBundle.manifestPath] = try JSONEncoder().encode(manifest)
        return files
    }

    @Test func aBundleHasAManifestRowsAndPhotoFiles() throws {
        let container = try populatedStore()
        let files = try BackupBundle.export(from: container.mainContext)
        let manifest = try manifest(of: files)
        #expect(manifest.formatVersion == BackupBundle.formatVersion)
        #expect(manifest.schemaVersion == "1.0.0")
        #expect(manifest.counts.photos == 1)
        #expect(manifest.counts.tags == 1)
        #expect(manifest.counts.people == 1)
        #expect(manifest.counts.trips == 1)
        #expect(manifest.counts.collections >= 3)
        #expect(manifest.counts.entries >= 1)
        #expect(files[BackupBundle.dataPath] != nil)
        #expect(files.keys.filter { $0.hasPrefix("photos/") }.count == 2)
        // Every file but the manifest is listed with its checksum.
        #expect(Set(manifest.files.keys) == Set(files.keys).subtracting([BackupBundle.manifestPath]))
    }

    @Test func exportThenWipeThenImportGivesIdenticalData() throws {
        let original = try populatedStore()
        let files = try BackupBundle.export(from: original.mainContext)

        // A new, empty store: the "wipe".
        let restored = try AsvadaStore.makeContainer(.inMemory)
        let summary = try BackupBundle.importFiles(files, into: restored.mainContext)
        let manifest = try manifest(of: files)
        #expect(summary.added == manifest.counts)
        #expect(summary.skipped == BackupBundle.Counts())

        // Exporting what was restored gives the same files, byte for byte (the manifest only
        // differs by its creation time).
        let again = try BackupBundle.export(from: restored.mainContext)
        #expect(Set(again.keys) == Set(files.keys))
        for path in files.keys where path != BackupBundle.manifestPath {
            #expect(again[path] == files[path], "\(path) changed in the round trip")
        }
        let restoredManifest = try self.manifest(of: again)
        #expect(restoredManifest.files == manifest.files)
        #expect(restoredManifest.counts == manifest.counts)
    }

    @Test func linksAndDetailsComeBackToo() throws {
        let original = try populatedStore()
        let files = try BackupBundle.export(from: original.mainContext)
        let restored = try AsvadaStore.makeContainer(.inMemory)
        try BackupBundle.importFiles(files, into: restored.mainContext)

        let entries = try restored.mainContext.fetch(FetchDescriptor<Entry>())
        let entry = try #require(entries.first { $0.notes == "Rainy Tuesday" })
        #expect(entry.date == Date(timeIntervalSinceReferenceDate: 786_000_000.123_456))
        #expect(entry.rating == 4.5)
        #expect(entry.item?.collection?.kind == .films)
        #expect(entry.item?.metadataJSON == Data(#"{"poster":"/p.jpg"}"#.utf8))
        #expect(entry.trip?.name == "Japan")
        #expect(entry.tags?.map(\.name) == ["rainy day"])
        #expect(entry.people?.map(\.name) == ["Ana"])
        #expect(entry.extraJSON == Data(#"{"Seat":"F12"}"#.utf8))
        let photo = try #require(entry.photos?.first)
        #expect(photo.imageData == Data([1, 2, 3, 4]))
        #expect(photo.thumbnailData == Data([9, 8]))
        #expect(photo.latitude == 35.0)
        let films = try #require(entry.item?.collection)
        #expect(films.accentName == "film")
        #expect(films.fieldSchemaJSON == Data(#"[{"name":"Seat","type":"text"}]"#.utf8))
    }

    @Test func importingTheSameBundleAgainAddsNothing() throws {
        let container = try populatedStore()
        let files = try BackupBundle.export(from: container.mainContext)
        let manifest = try manifest(of: files)
        let summary = try BackupBundle.importFiles(files, into: container.mainContext)
        #expect(summary.added == BackupBundle.Counts())
        #expect(summary.skipped == manifest.counts)
        let after = try BackupBundle.export(from: container.mainContext)
        #expect(after[BackupBundle.dataPath] == files[BackupBundle.dataPath])
    }

    @Test func aChangedFileIsRefusedAndNothingIsImported() throws {
        let container = try populatedStore()
        var files = try BackupBundle.export(from: container.mainContext)
        let photoPath = try #require(files.keys.first { $0.hasSuffix(".photo") })
        files[photoPath] = Data([0, 0, 0])
        let empty = try AsvadaStore.makeContainer(.inMemory)
        #expect(throws: BackupBundle.BackupError.checksumMismatch(photoPath)) {
            try BackupBundle.importFiles(files, into: empty.mainContext)
        }
        #expect(try empty.mainContext.fetch(FetchDescriptor<ExperienceCollection>()).isEmpty)
    }

    @Test func aMissingFileIsRefused() throws {
        let container = try populatedStore()
        var files = try BackupBundle.export(from: container.mainContext)
        let thumbPath = try #require(files.keys.first { $0.hasSuffix(".thumb") })
        files[thumbPath] = nil
        let empty = try AsvadaStore.makeContainer(.inMemory)
        #expect(throws: BackupBundle.BackupError.missingFile(thumbPath)) {
            try BackupBundle.importFiles(files, into: empty.mainContext)
        }
        files[BackupBundle.manifestPath] = nil
        #expect(throws: BackupBundle.BackupError.missingFile(BackupBundle.manifestPath)) {
            try BackupBundle.importFiles(files, into: empty.mainContext)
        }
    }

    @Test func aNewerFormatIsRefused() throws {
        let container = try populatedStore()
        let files = try BackupBundle.export(from: container.mainContext)
        var manifest = try manifest(of: files)
        manifest.formatVersion = BackupBundle.formatVersion + 1
        let newer = try rewrite(manifest, in: files)
        let empty = try AsvadaStore.makeContainer(.inMemory)
        #expect(throws: BackupBundle.BackupError.unsupportedFormat(BackupBundle.formatVersion + 1)) {
            try BackupBundle.importFiles(newer, into: empty.mainContext)
        }
    }

    @Test func countsThatDontAddUpAreRefused() throws {
        let container = try populatedStore()
        let files = try BackupBundle.export(from: container.mainContext)
        var manifest = try manifest(of: files)
        manifest.counts.entries += 1
        let wrong = try rewrite(manifest, in: files)
        let empty = try AsvadaStore.makeContainer(.inMemory)
        #expect(throws: BackupBundle.BackupError.countMismatch) {
            try BackupBundle.importFiles(wrong, into: empty.mainContext)
        }
    }

    @Test func aBundleSurvivesBeingWrittenToAFolderAndReadBack() throws {
        let container = try populatedStore()
        let files = try BackupBundle.export(from: container.mainContext)
        let folder = FileManager.default.temporaryDirectory.appending(path: "backup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try BackupBundle.write(files, to: folder)
        let read = try BackupBundle.read(from: folder)
        #expect(read == files)
        let restored = try AsvadaStore.makeContainer(.inMemory)
        try BackupBundle.importFiles(read, into: restored.mainContext)
        #expect(try restored.mainContext.fetch(FetchDescriptor<Photo>()).count == 1)
    }
}
