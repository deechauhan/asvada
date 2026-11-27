import DesignSystem
import Model
import SwiftData
import SwiftUI

/// A place on the map: a small keepsake-paper disc in its collection's icon, ringed in the
/// collection's ink (#51).
struct AtlasPinView: View {
    let item: Item

    var body: some View {
        let ink = item.collection?.accent.token.color ?? Palette.brand.color
        Image(systemName: item.collection?.icon ?? "mappin")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(ink)
            .frame(width: 32, height: 32)
            .background(Palette.keepsakePaper.color, in: Circle())
            .overlay(Circle().strokeBorder(ink, lineWidth: 2.5))
            .shadow(color: Palette.textPrimary.color.opacity(0.25), radius: 3, y: 2)
            .contentShape(Circle())
            .accessibilityLabel(item.name)
            .accessibilityHint("Shows this place")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("atlasPin")
    }
}

/// The preview card a pin opens: what the place is, how often and when you savoured it, and a
/// way into its page.
struct AtlasPinCard: View {
    let itemID: UUID
    @Query private var items: [Item]
    @Environment(\.dismiss) private var dismiss

    private var item: Item? {
        items.first { $0.id == itemID }
    }

    var body: some View {
        NavigationStack {
            List {
                if let item {
                    Section {
                        HStack(spacing: Spacing.medium) {
                            AtlasPinView(item: item)
                                .allowsHitTesting(false)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(item.name)
                                    .typeToken(.title)
                                    .foregroundStyle(Palette.textPrimary.color)
                                if let collection = item.collection {
                                    Text(collection.name)
                                        .typeToken(.caption)
                                        .foregroundStyle(Palette.textSecondary.color)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        Text(AtlasLogic.visitLine(entryDates: (item.entries ?? []).map(\.date)))
                            .typeToken(.callout)
                            .foregroundStyle(Palette.textSecondary.color)
                            .accessibilityIdentifier("atlasPinSummary")
                    }
                    Section {
                        NavigationLink {
                            ItemDetailScreen(item: item)
                        } label: {
                            Label("Open \(item.name)", systemImage: "arrow.right.circle")
                        }
                        .accessibilityIdentifier("atlasPinOpen")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("On the map")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("atlasPinCard")
    }
}
