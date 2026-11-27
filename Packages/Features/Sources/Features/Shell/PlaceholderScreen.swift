import DesignSystem
import SwiftUI

/// Settings placeholder with About and a link to the design catalogue.
struct SettingsScreen: View {
    @Environment(AppLockModel.self) private var lock

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
                Section("Photos") {
                    NavigationLink {
                        PhotoBackfillView()
                    } label: {
                        Label("Find places in my photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .accessibilityIdentifier("photoPlacesLink")
                }
                Section {
                    OnThisDayReminderToggle()
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A note at 9 in the morning when something you savoured happened on that day in an earlier year.")
                }
                AppLockSettingsSection(model: lock)
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
