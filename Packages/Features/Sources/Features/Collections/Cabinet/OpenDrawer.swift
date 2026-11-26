import DesignSystem
import Model
import SwiftUI

/// An opened drawer: its keepsakes laid out one above another, best (or newest) first. This is
/// the interim interior; the riffle (thumbing through keepsakes stood on end) replaces it.
/// Its toolbar customises and shares the drawer directly, without the chest's hold menu.
struct OpenDrawer: View {
    let collection: ExperienceCollection
    @State private var isCustomising = false
    @State private var isSharing = false
    @State private var isAddingByHand = false

    private var items: [Item] {
        ExperienceCollection.drawerOrder(collection.items ?? [], mode: collection.ratingMode)
    }

    var body: some View {
        // Deleted from Customise: nothing to show while the screen pops back to the cabinet.
        if collection.isDeleted || collection.modelContext == nil {
            Color.clear
        } else {
            drawer
        }
    }

    private var drawer: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.large) {
                // Countries is a checklist against the world: its progress and stamp pad lead.
                if collection.kind == .countries {
                    PassportPanel(collection: collection)
                }
                if items.isEmpty, collection.kind != .countries {
                    VStack(spacing: Spacing.medium) {
                        GhostSlip(kind: collection.kind)
                        Text("Nothing savoured yet")
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    .padding(.top, Spacing.xl)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // Tap a keepsake for the thing's own page.
                    NavigationLink {
                        ItemDetailScreen(item: item)
                    } label: {
                        ItemKeepsake(
                            item: item,
                            collection: collection,
                            rank: collection.ratingMode == .ranked ? index + 1 : nil,
                        )
                    }
                    .buttonStyle(.plain)
                    .paperTilt(index.isMultiple(of: 2) ? -1.2 : 1)
                }
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("openDrawer")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Only filled drawers have something to share.
                if ShareContent(collection: collection) != nil {
                    Button("Share", systemImage: "square.and.arrow.up") { isSharing = true }
                        .accessibilityIdentifier("drawerShare")
                }
                Button("Add by hand", systemImage: "square.and.pencil") { isAddingByHand = true }
                    .accessibilityIdentifier("drawerAddByHand")
                Button("Customise", systemImage: "slider.horizontal.3") { isCustomising = true }
                    .accessibilityIdentifier("drawerCustomise")
            }
        }
        .sheet(isPresented: $isAddingByHand) {
            ManualItemSheet(collection: collection)
        }
        .sheet(isPresented: $isCustomising) {
            CollectionEditor(mode: .edit(collection))
        }
        .sheet(isPresented: $isSharing) {
            if let content = ShareContent(collection: collection) {
                ShareCardSheet(collection: collection, content: content)
            }
        }
    }
}
