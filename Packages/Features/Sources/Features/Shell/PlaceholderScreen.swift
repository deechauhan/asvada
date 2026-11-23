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
                Section("Developer") {
                    NavigationLink("Design catalogue") {
                        DesignCatalogView()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle(AppTab.settings.title)
        }
    }
}
