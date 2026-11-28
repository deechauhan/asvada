import Foundation
import Storage

/// The words the restore screen uses: what a backup holds, and what went wrong with one.
enum RestoreText {
    private struct Part {
        let number: Int
        let one: String
        let many: String
    }

    /// "12 entries · 5 items · 3 collections": the non-zero counts, entries first. Empty when none.
    static func summary(_ counts: BackupBundle.Counts) -> String {
        let parts = [
            Part(number: counts.entries, one: "entry", many: "entries"),
            Part(number: counts.items, one: "item", many: "items"),
            Part(number: counts.collections, one: "collection", many: "collections"),
            Part(number: counts.photos, one: "photo", many: "photos"),
            Part(number: counts.trips, one: "trip", many: "trips"),
            Part(number: counts.people, one: "person", many: "people"),
            Part(number: counts.tags, one: "tag", many: "tags"),
        ]
        return parts
            .filter { $0.number > 0 }
            .map { "\($0.number) \($0.number == 1 ? $0.one : $0.many)" }
            .joined(separator: " · ")
    }

    /// Whether restoring would change anything.
    static func addsAnything(_ counts: BackupBundle.Counts) -> Bool {
        !summary(counts).isEmpty
    }

    /// A reason in plain words for a backup that couldn't be read or restored.
    static func message(for error: any Error) -> String {
        guard let error = error as? BackupBundle.BackupError else {
            return "That folder couldn't be read: \(error.localizedDescription)"
        }
        switch error {
        case .unsupportedFormat:
            return "This backup was made by a newer version of Artifacts. Update the app, then try again."
        case .missingFile, .checksumMismatch, .countMismatch, .unreadable:
            return "This backup looks damaged or incomplete, so nothing was restored."
        }
    }
}
