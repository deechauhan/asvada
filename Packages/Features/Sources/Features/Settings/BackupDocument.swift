import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A backup bundle as a folder the Files app can save (`fileExporter`): `manifest.json`,
/// `data.json` and a `photos` folder (docs/BACKUP_FORMAT.md). It reads back the same way, so the
/// folder a backup was saved as is the folder Restore picks.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.folder]
    }

    static var writableContentTypes: [UTType] {
        [.folder]
    }

    /// The bundle's files, keyed by their path inside it.
    let files: [String: Data]

    init(files: [String: Data]) {
        self.files = files
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isDirectory else { throw CocoaError(.fileReadCorruptFile) }
        files = Self.files(in: configuration.file)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        Self.wrapper(for: files)
    }

    /// A folder wrapper holding `files`, with subfolders made from the paths ("photos/<id>.photo").
    static func wrapper(for files: [String: Data]) -> FileWrapper {
        let root = FileWrapper(directoryWithFileWrappers: [:])
        for (path, contents) in files.sorted(by: { $0.key < $1.key }) {
            let parts = path.split(separator: "/").map(String.init)
            guard let name = parts.last else { continue }
            var folder = root
            for part in parts.dropLast() {
                if let existing = folder.fileWrappers?[part] {
                    folder = existing
                } else {
                    let made = FileWrapper(directoryWithFileWrappers: [:])
                    made.preferredFilename = part
                    folder.addFileWrapper(made)
                    folder = made
                }
            }
            let file = FileWrapper(regularFileWithContents: contents)
            file.preferredFilename = name
            folder.addFileWrapper(file)
        }
        return root
    }

    /// The files inside a folder wrapper, keyed by their path from it.
    static func files(in wrapper: FileWrapper, prefix: String = "") -> [String: Data] {
        var found: [String: Data] = [:]
        for (name, child) in wrapper.fileWrappers ?? [:] {
            if child.isDirectory {
                found.merge(files(in: child, prefix: prefix + name + "/")) { first, _ in first }
            } else if let contents = child.regularFileContents {
                found[prefix + name] = contents
            }
        }
        return found
    }
}
