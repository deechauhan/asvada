import Foundation
import Model
import Storage
import SwiftData
import Testing
@testable import Features

@MainActor
struct BackupDocumentTests {
    @Test func thePathsBecomeFoldersInTheWrapper() throws {
        let files = [
            "manifest.json": Data("m".utf8),
            "data.json": Data("d".utf8),
            "photos/a.photo": Data([1]),
            "photos/a.thumb": Data([2]),
        ]
        let root = BackupDocument.wrapper(for: files)
        #expect(root.isDirectory)
        let children = try #require(root.fileWrappers)
        #expect(Set(children.keys) == ["manifest.json", "data.json", "photos"])
        let photos = try #require(children["photos"])
        #expect(photos.isDirectory)
        let photoFiles = try #require(photos.fileWrappers)
        #expect(Set(photoFiles.keys) == ["a.photo", "a.thumb"])
        #expect(children["data.json"]?.regularFileContents == Data("d".utf8))
    }

    @Test func aWrapperReadsBackToTheSameFiles() {
        let files = [
            "manifest.json": Data("m".utf8),
            "data.json": Data("d".utf8),
            "photos/a.photo": Data([1, 2, 3]),
            "photos/b.thumb": Data([4]),
        ]
        #expect(BackupDocument.files(in: BackupDocument.wrapper(for: files)) == files)
    }

    @Test func aRealBackupSurvivesBeingSavedAsAFolderAndRestoredFromIt() throws {
        let container = try AsvadaStore.makeContainer(.inMemory)
        let repository = Repository(context: container.mainContext)
        try BuiltInCollections.seedIfNeeded(in: repository.context)
        try PreviewData.fillBuiltIns(repository)
        let files = try BackupBundle.export(from: container.mainContext)

        let folder = BackupDocument.files(in: BackupDocument.wrapper(for: files))
        #expect(folder == files)
        let restored = try AsvadaStore.makeContainer(.inMemory)
        let summary = try BackupBundle.importFiles(folder, into: restored.mainContext)
        #expect(RestoreText.addsAnything(summary.added))
        #expect(try BackupBundle.export(from: restored.mainContext)[BackupBundle.dataPath] == files[BackupBundle.dataPath])
    }

    @Test func theFolderIsNamedForTheDay() {
        let day = Date(timeIntervalSince1970: 1_795_000_000)
        #expect(ExportBackupView.filename(for: day).hasPrefix("Asvada backup 20"))
    }
}
