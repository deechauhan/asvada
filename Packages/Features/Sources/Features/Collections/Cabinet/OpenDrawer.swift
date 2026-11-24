import DesignSystem
import Model
import SwiftUI

/// An opened drawer: its keepsakes laid out one above another, best (or newest) first. This is
/// the interim interior; the riffle (thumbing through keepsakes stood on end) replaces it.
struct OpenDrawer: View {
    let collection: ExperienceCollection

    private var items: [Item] {
        ExperienceCollection.drawerOrder(collection.items ?? [], mode: collection.ratingMode)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.large) {
                if items.isEmpty {
                    VStack(spacing: Spacing.medium) {
                        GhostSlip(kind: collection.kind)
                        Text("Nothing savoured yet")
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    .padding(.top, Spacing.xl)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ItemKeepsake(
                        item: item,
                        collection: collection,
                        rank: collection.ratingMode == .ranked ? index + 1 : nil,
                    )
                    .paperTilt(index.isMultiple(of: 2) ? -1.2 : 1)
                }
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("openDrawer")
    }
}
