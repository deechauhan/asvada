import DesignSystem
import Storage
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Back up to the Files app (#59): everything as a folder you own, with no iCloud involved. The
/// folder is the backup bundle (docs/BACKUP_FORMAT.md); Restore reads it back.
struct ExportBackupView: View {
    @Environment(\.modelContext) private var context

    private enum Stage {
        case ready
        case saved(counts: BackupBundle.Counts)
        case failed(String)
    }

    @State private var stage = Stage.ready
    @State private var document = BackupDocument(files: [:])
    @State private var isExporting = false

    var body: some View {
        List {
            Section {
                Text(
                    """
                    Save everything you've savoured as a folder in Files. It's yours: keep it anywhere, \
                    and restore it here or on another phone.
                    """,
                )
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                Button("Save a backup to Files…", systemImage: "square.and.arrow.up") {
                    prepare()
                }
                .accessibilityIdentifier("exportBackupButton")
            }
            switch stage {
            case .ready:
                EmptyView()
            case let .saved(counts):
                Section {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .typeToken(.headline)
                        .foregroundStyle(Palette.brand.color)
                    Text(RestoreText.summary(counts))
                        .typeToken(.body)
                        .accessibilityIdentifier("exportDone")
                }
            case let .failed(message):
                Section {
                    Text(message)
                        .typeToken(.body)
                        .accessibilityIdentifier("exportError")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("Back up")
        .fileExporter(
            isPresented: $isExporting,
            document: document,
            contentType: .folder,
            defaultFilename: Self.filename(for: .now),
        ) { result in
            finish(result)
        }
    }

    /// The folder's default name: "Artifacts backup 2026-11-26".
    static func filename(for date: Date) -> String {
        "Artifacts backup \(date.formatted(.iso8601.year().month().day()))"
    }

    /// Reads the whole store into a bundle and opens the Files picker to save it.
    private func prepare() {
        do {
            document = try BackupDocument(files: BackupBundle.export(from: context))
            isExporting = true
        } catch {
            stage = .failed("The backup couldn't be made: \(error.localizedDescription)")
        }
    }

    private func finish(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            let manifest = try? JSONDecoder().decode(
                BackupBundle.Manifest.self,
                from: document.files[BackupBundle.manifestPath] ?? Data(),
            )
            stage = .saved(counts: manifest?.counts ?? BackupBundle.Counts())
        case let .failure(error):
            // Dismissing the picker isn't an error.
            if (error as? CocoaError)?.code != .userCancelled {
                stage = .failed("The backup couldn't be saved: \(error.localizedDescription)")
            }
        }
    }
}
