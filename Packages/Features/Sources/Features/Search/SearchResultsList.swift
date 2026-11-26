import DesignSystem
import Model
import SwiftData
import SwiftUI

/// What shows under the search field on the Journal and in Collections: the items that match,
/// grouped by collection. Tapping a result opens the item.
struct SearchResultsList: View {
    @Query private var items: [Item]
    let query: String

    private var groups: [SearchGroup] {
        GlobalSearch.groups(for: query, in: items)
    }

    var body: some View {
        let groups = groups
        Group {
            if groups.isEmpty {
                ContentUnavailableView.search(text: GlobalSearch.trimmed(query))
                    .accessibilityIdentifier("searchNoResults")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        ForEach(groups) { group in
                            SearchGroupSection(group: group)
                        }
                    }
                    .padding(Spacing.large)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
        .accessibilityIdentifier("searchResults")
    }
}

/// One collection's results under its name.
private struct SearchGroupSection: View {
    let group: SearchGroup

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label(group.collection.name, systemImage: group.collection.icon)
                .typeToken(.headline)
                .foregroundStyle(group.collection.accent.token.color)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.hits) { hit in
                NavigationLink {
                    ItemDetailScreen(item: hit.item)
                } label: {
                    SearchRow(hit: hit, accent: group.collection.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("searchResult")
            }
        }
    }
}

/// One result: the item's name, and what matched when it wasn't the name.
private struct SearchRow: View {
    let hit: SearchHit
    let accent: CollectionAccent

    var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(hit.item.name)
                    .typeToken(.body)
                    .foregroundStyle(Palette.textPrimary.color)
                if let caption = hit.match.caption {
                    Text(caption)
                        .typeToken(.caption)
                        .foregroundStyle(Palette.textSecondary.color)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityHidden(true)
        }
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent.token.color)
                .frame(width: 3)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(hit.item.name)")
    }
}
