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

/// Settings placeholder with an About section and a link to the design catalogue.
struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("App", value: "Asvada")
                    Text("āsvāda (आस्वाद), Sanskrit: savouring, relish.")
                        .typeToken(.callout)
                        .foregroundStyle(Palette.textSecondary.color)
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
