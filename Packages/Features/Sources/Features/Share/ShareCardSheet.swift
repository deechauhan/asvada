import DesignSystem
import Model
import SwiftUI

/// What a collection shares: ranked collections their top five as a menu, countries the passport
/// spread, everything else its best keepsake. Empty collections have nothing to share.
enum ShareContent {
    case topMenu(collection: String, courses: [TopMenuCard.Course])
    case passport([StampEntry])
    case keepsake(Item)

    init?(collection: ExperienceCollection) {
        let items = collection.drawerItems(limit: .max)
        guard let best = items.first else { return nil }
        if collection.kind == .countries {
            // The spread reads in the order you got the stamps.
            let byEntry = items.sorted { ($0.firstEncountered ?? .distantFuture) < ($1.firstEncountered ?? .distantFuture) }
            self = .passport(byEntry.map { StampEntry(country: $0.name, code: $0.isoCode, date: $0.firstEncountered) })
        } else if collection.ratingMode == .ranked {
            let courses = items.prefix(5).map { item in
                TopMenuCard.Course(name: item.name, detail: item.latestEntry.map { KeepsakeDate.short($0.date) })
            }
            self = .topMenu(collection: collection.name, courses: courses)
        } else {
            self = .keepsake(best)
        }
    }
}

/// Shows a collection's share card and offers it, rendered at 3×, to the share sheet.
struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let collection: ExperienceCollection
    let content: ShareContent

    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                card
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                    .shadow(color: Palette.textPrimary.color.opacity(0.2), radius: 16, y: 10)
                    .accessibilityIdentifier("shareCardPreview")
                if let image {
                    ShareLink(
                        item: image,
                        preview: SharePreview("\(collection.name) · Asvada", image: image),
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .typeToken(.headline)
                            .frame(maxWidth: 280)
                            .padding(.vertical, Spacing.small)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.brand.color)
                    .accessibilityIdentifier("shareCardButton")
                } else {
                    ProgressView()
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.color)
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("shareCardDone")
                }
            }
            .task {
                image = ShareCard.render(card)
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        switch content {
        case let .topMenu(name, courses):
            TopMenuCard(collection: name, courses: courses)
        case let .passport(stamps):
            PassportSpreadCard(stamps: stamps)
        case let .keepsake(item):
            KeepsakeShareCard(eyebrow: collection.name, title: item.name) {
                ItemKeepsake(item: item, collection: collection, rank: collection.ratingMode == .ranked ? 1 : nil)
            }
        }
    }
}
