import DesignSystem
import Storage
import SwiftData
import SwiftUI

/// Delete all data (#60): everything saved on this phone, after two confirmations and an offer of
/// a backup first. Nothing in iCloud or in a backup folder you saved is touched.
struct DeleteDataView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("cabinet.front") private var frontID = ""

    private enum Stage: Equatable {
        case ready
        case deleted(String)
        case failed(String)
    }

    @State private var stage = Stage.ready
    @State private var isAsking = false
    @State private var isSure = false

    var body: some View {
        List {
            Section {
                Text(
                    """
                    This deletes every keepsake, photo, note, rating and collection on this phone, and \
                    can't be undone. Backups you saved in Files or iCloud aren't touched.
                    """,
                )
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                NavigationLink {
                    ExportBackupView()
                } label: {
                    Label("Back up first", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("backUpFirstLink")
            }
            Section {
                Button("Delete all data…", systemImage: "trash", role: .destructive) {
                    isAsking = true
                }
                .accessibilityIdentifier("deleteAllButton")
            }
            switch stage {
            case .ready:
                EmptyView()
            case let .deleted(summary):
                Section {
                    Label("Deleted", systemImage: "checkmark.circle.fill")
                        .typeToken(.headline)
                        .foregroundStyle(Palette.brand.color)
                    Text(summary)
                        .typeToken(.body)
                        .accessibilityIdentifier("deleteDone")
                }
            case let .failed(message):
                Section {
                    Text(message)
                        .typeToken(.body)
                        .accessibilityIdentifier("deleteError")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("Delete data")
        // First ask: a sheet that names what's at stake.
        .confirmationDialog("Delete all data?", isPresented: $isAsking, titleVisibility: .visible) {
            Button("Continue…", role: .destructive) {
                isSure = true
            }
            .accessibilityIdentifier("deleteContinue")
        } message: {
            Text("Everything you've savoured on this phone will go.")
        }
        // Second ask: the last word.
        .alert("Really delete everything?", isPresented: $isSure) {
            Button("Cancel", role: .cancel) {}
            Button("Yes, delete everything", role: .destructive) {
                erase()
            }
            .accessibilityIdentifier("deleteConfirm")
        } message: {
            Text("There's no undo. Back up first if you might want it back.")
        }
    }

    private func erase() {
        do {
            let deleted = try Repository(context: context).eraseEverything()
            frontID = ""
            let summary = RestoreText.summary(deleted)
            stage = .deleted(summary.isEmpty ? "There was nothing to delete." : "Deleted \(summary).")
        } catch {
            stage = .failed("Nothing was deleted: \(error.localizedDescription)")
        }
    }
}
