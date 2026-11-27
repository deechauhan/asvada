import DesignSystem
import Geo
import Model
import SwiftData
import SwiftUI

/// What you've savoured in one country (#49): every entry logged there, newest first, each
/// opening its item. A country with nothing in it says so and where to stamp it, never a bare 0.
struct AtlasCountrySheet: View {
    let code: String
    let isVisited: Bool
    /// What the map is filtered to; the sheet lists only the entries that pass.
    var filter = AtlasFilter()
    @Query private var entries: [Entry]
    @Environment(\.dismiss) private var dismiss

    private var country: Country? {
        CountryCatalog.shared.country(code: code)
    }

    private var inCountry: [Entry] {
        AtlasLogic.entries(inCountry: code, from: filter.apply(to: entries))
    }

    var body: some View {
        NavigationStack {
            List {
                if let country {
                    if inCountry.isEmpty {
                        Section {
                            Text(AtlasLogic.emptyLine(for: country, isVisited: isVisited))
                                .typeToken(.callout)
                                .foregroundStyle(Palette.textSecondary.color)
                                .accessibilityIdentifier("atlasEmpty")
                        }
                    } else {
                        Section {
                            ForEach(inCountry) { entry in
                                if let item = entry.item {
                                    NavigationLink {
                                        ItemDetailScreen(item: item)
                                    } label: {
                                        AtlasEntryRow(entry: entry, item: item)
                                    }
                                    .accessibilityIdentifier("atlasEntry")
                                }
                            }
                        } header: {
                            Text(AtlasLogic.entryCount(inCountry.count))
                        } footer: {
                            if filter.isActive {
                                Text("Only what passes the map's filters.")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle(country.map { "\($0.flag) \($0.name)" } ?? code)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("atlasCountrySheet")
    }
}

/// An entry made in a country: what it was, in its collection's colour, and when.
private struct AtlasEntryRow: View {
    let entry: Entry
    let item: Item

    var body: some View {
        HStack(spacing: Spacing.medium) {
            if let collection = item.collection {
                Image(systemName: collection.icon)
                    .foregroundStyle(collection.accent.token.color)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.name)
                    .typeToken(.body)
                    .foregroundStyle(Palette.textPrimary.color)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
