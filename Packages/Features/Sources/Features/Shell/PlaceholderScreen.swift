import DesignSystem
import SwiftUI

/// A titled empty state used until a tab's real screen is built.
struct PlaceholderScreen: View {
    let tab: AppTab
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(tab.title, systemImage: tab.symbol)
            } description: {
                Text(message)
            }
            .foregroundStyle(Palette.textSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.color)
            .navigationTitle(tab.title)
        }
    }
}

/// Settings placeholder with About and a link to the design catalogue.
struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        LabeledContent("About Asvada", value: AppVersion.current.version)
                    }
                    .accessibilityIdentifier("aboutLink")
                }
                Section("Your data") {
                    NavigationLink {
                        ExportBackupView()
                    } label: {
                        Label("Back up to Files", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportBackupLink")
                    NavigationLink {
                        RestoreBackupView()
                    } label: {
                        Label("Restore from a backup", systemImage: "arrow.down.doc")
                    }
                    .accessibilityIdentifier("restoreBackupLink")
                }
                Section("Privacy") {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("What leaves this phone", systemImage: "lock.shield")
                    }
                    .accessibilityIdentifier("privacyLink")
                    NavigationLink {
                        DeleteDataView()
                    } label: {
                        Label("Delete all data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteDataLink")
                }
                Section("Developer") {
                    NavigationLink("Design catalogue") {
                        DesignCatalogView()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Settings")
        }
    }
}
