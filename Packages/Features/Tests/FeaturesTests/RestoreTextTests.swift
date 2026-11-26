import Foundation
import Storage
import Testing
@testable import Features

struct RestoreTextTests {
    @Test func summaryListsTheNonZeroCountsEntriesFirst() {
        var counts = BackupBundle.Counts()
        counts.collections = 3
        counts.items = 5
        counts.entries = 12
        counts.photos = 1
        #expect(RestoreText.summary(counts) == "12 entries · 5 items · 3 collections · 1 photo")
    }

    @Test func oneOfSomethingIsSingular() {
        var counts = BackupBundle.Counts()
        counts.entries = 1
        counts.people = 1
        #expect(RestoreText.summary(counts) == "1 entry · 1 person")
    }

    @Test func nothingIsEmptyAndAddsNothing() {
        #expect(RestoreText.summary(BackupBundle.Counts()).isEmpty)
        #expect(!RestoreText.addsAnything(BackupBundle.Counts()))
        var counts = BackupBundle.Counts()
        counts.tags = 2
        #expect(RestoreText.addsAnything(counts))
    }

    @Test func aNewerBackupSaysToUpdateTheApp() {
        let message = RestoreText.message(for: BackupBundle.BackupError.unsupportedFormat(2))
        #expect(message.contains("newer version"))
    }

    @Test func aDamagedBackupSaysNothingWasRestored() {
        let errors: [BackupBundle.BackupError] = [
            .missingFile("data.json"), .checksumMismatch("data.json"), .countMismatch, .unreadable("manifest.json"),
        ]
        for error in errors {
            #expect(RestoreText.message(for: error).contains("nothing was restored"))
        }
    }

    @Test func otherErrorsSayTheFolderCouldntBeRead() {
        struct Unreadable: Error {}
        #expect(RestoreText.message(for: Unreadable()).hasPrefix("That folder couldn't be read"))
    }
}
