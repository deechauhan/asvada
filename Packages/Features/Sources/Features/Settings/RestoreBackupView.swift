import DesignSystem
import Storage
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Restore from a backup (#58): pick a backup folder, see what's in it and what would be added,
/// then agree. Anything already here (same id) is left alone, so restoring twice adds nothing.
struct RestoreBackupView: View {
    @Environment(\.modelContext) private var context

    private enum Stage {
        case choosing
        case preview(BackupBundle.Preview, files: [String: Data])
        case restored(BackupBundle.ImportSummary)
        case failed(String)
    }

    @State private var stage = Stage.choosing
    @State private var isPicking = false

    var body: some View {
        List {
            switch stage {
            case .choosing:
                choosing
            case let .preview(preview, files):
                previewSections(preview, files: files)
            case let .restored(summary):
                restored(summary)
            case let .failed(message):
                failed(message)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("Restore")
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { result in
            open(result)
        }
    }

    private var choosing: some View {
        Section {
            Text("Choose a backup folder. You'll see what's in it before anything changes, and nothing already here is replaced.")
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
            Button("Choose a backup…", systemImage: "folder") {
                isPicking = true
            }
            .accessibilityIdentifier("chooseBackupButton")
        }
    }

    @ViewBuilder
    private func previewSections(_ preview: BackupBundle.Preview, files: [String: Data]) -> some View {
        Section("In this backup") {
            Text(RestoreText.summary(preview.manifest.counts))
                .typeToken(.body)
            Text("Made \(preview.manifest.createdAt.formatted(date: .long, time: .shortened))")
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
        Section("Restoring will add") {
            if RestoreText.addsAnything(preview.summary.added) {
                Text(RestoreText.summary(preview.summary.added))
                    .typeToken(.body)
                    .accessibilityIdentifier("restoreWillAdd")
            } else {
                Text("Nothing: everything in this backup is already here.")
                    .typeToken(.body)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            if RestoreText.addsAnything(preview.summary.skipped) {
                Text("Already here, left as it is: \(RestoreText.summary(preview.summary.skipped))")
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        Section {
            Button("Restore", systemImage: "arrow.down.doc.fill") {
                restore(files)
            }
            .disabled(!RestoreText.addsAnything(preview.summary.added))
            .accessibilityIdentifier("restoreButton")
            Button("Choose a different backup", systemImage: "folder") {
                isPicking = true
            }
        }
    }

    private func restored(_ summary: BackupBundle.ImportSummary) -> some View {
        Section {
            Label("Restored", systemImage: "checkmark.circle.fill")
                .typeToken(.headline)
                .foregroundStyle(Palette.brand.color)
            Text("Added \(RestoreText.summary(summary.added)).")
                .typeToken(.body)
                .accessibilityIdentifier("restoreDone")
        }
    }

    private func failed(_ message: String) -> some View {
        Section {
            Text(message)
                .typeToken(.body)
                .accessibilityIdentifier("restoreError")
            Button("Choose a different backup", systemImage: "folder") {
                isPicking = true
            }
        }
    }

    /// Reads the folder the picker returned and shows what restoring it would do.
    private func open(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            // The folder lives outside the app, so it must be unlocked while it's read.
            let unlocked = url.startAccessingSecurityScopedResource()
            defer {
                if unlocked {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let files = try BackupBundle.read(from: url)
            stage = try .preview(BackupBundle.preview(files, in: context), files: files)
        } catch {
            stage = .failed(RestoreText.message(for: error))
        }
    }

    private func restore(_ files: [String: Data]) {
        do {
            stage = try .restored(BackupBundle.importFiles(files, into: context))
        } catch {
            stage = .failed(RestoreText.message(for: error))
        }
    }
}
