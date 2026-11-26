import DesignSystem
import Model
import SwiftUI

/// An opened drawer. Its keepsakes stand on end in the riffle (#156): thumb through them, tap a
/// tab or the rail to jump, tap the front one to lift it out. Pinch, or tap Spread, to tip them
/// out into the spread, where tapping one goes back to the riffle at that card; until the four
/// spreads land (#44) the spread is a plain column of keepsakes. Countries keeps its passport,
/// and at the largest text sizes (AX3 and up) every drawer opens straight into its spread.
/// The toolbar customises, shares, re-orders and adds to the drawer.
struct OpenDrawer: View {
    let collection: ExperienceCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCustomising = false
    @State private var isSharing = false
    @State private var isAddingByHand = false
    @State private var isReordering = false
    @State private var isSpread = false
    /// The card at the front of the riffle.
    @State private var front = 0
    /// The keepsake lifted out of the riffle into its item page.
    @State private var lifted: Item?
    @State private var lifts = 0
    @State private var clunks = 0
    @Namespace private var cardZoom

    private var items: [Item] {
        ExperienceCollection.drawerOrder(collection.items ?? [], mode: collection.ratingMode)
    }

    private var riffleIndex: RiffleIndex {
        RiffleIndex.make(items: collection.items ?? [], mode: collection.ratingMode)
    }

    /// Whether this drawer has a riffle at all: not Countries (its passport is its own view), not
    /// an empty drawer, and not at AX3 and above.
    private var hasRiffle: Bool {
        collection.kind != .countries && !items.isEmpty && typeSize < .accessibility3
    }

    private var showsSpread: Bool {
        !hasRiffle || isSpread
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
        Group {
            if showsSpread {
                spread
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                RiffleView(
                    collection: collection,
                    index: riffleIndex,
                    front: $front,
                    namespace: cardZoom,
                    lift: liftOut,
                    shut: shut,
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .simultaneousGesture(pinch, including: hasRiffle ? .all : .subviews)
        .background(Palette.background.color)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("openDrawer")
        .toolbar { toolbar }
        .navigationDestination(item: $lifted) { item in
            ItemDetailScreen(item: item)
                .zoomTransition(id: item.id.uuidString, in: cardZoom)
        }
        .haptic(.lift, trigger: lifts)
        .haptic(.clunk, trigger: clunks)
        .sheet(isPresented: $isReordering) {
            RankReorderSheet(collection: collection)
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if hasRiffle {
                Button(isSpread ? "Riffle" : "Spread", systemImage: isSpread ? "rectangle.stack" : "square.grid.2x2") {
                    setSpread(!isSpread)
                }
                .accessibilityIdentifier("drawerSpread")
            }
            // Only filled drawers have something to share.
            if ShareContent(collection: collection) != nil {
                Button("Share", systemImage: "square.and.arrow.up") { isSharing = true }
                    .accessibilityIdentifier("drawerShare")
            }
            // Ranked drawers can be re-ordered by hand (#41).
            if collection.ratingMode == .ranked, items.count > 1 {
                Button("Re-order", systemImage: "arrow.up.arrow.down") { isReordering = true }
                    .accessibilityIdentifier("drawerReorder")
            }
            Button("Add by hand", systemImage: "square.and.pencil") { isAddingByHand = true }
                .accessibilityIdentifier("drawerAddByHand")
            Button("Customise", systemImage: "slider.horizontal.3") { isCustomising = true }
                .accessibilityIdentifier("drawerCustomise")
        }
    }

    // MARK: - The spread

    /// Every keepsake at once, one above another. In a drawer with a riffle, tapping one goes back
    /// to the riffle at that card; otherwise it opens the thing's page.
    private var spread: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.large) {
                // Countries is a checklist against the world: its progress and stamp pad lead.
                if collection.kind == .countries {
                    PassportPanel(collection: collection)
                }
                if items.isEmpty, collection.kind != .countries {
                    VStack(spacing: Spacing.medium) {
                        GhostSlip(kind: collection.kind)
                        Text("Nothing savoured yet. Hold Savour something to draw your first.")
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(Palette.textSecondary.color)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.xl)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    spreadCard(item, rank: collection.ratingMode == .ranked ? index + 1 : nil)
                        .paperTilt(index.isMultiple(of: 2) ? -1.2 : 1)
                }
            }
            .padding(Spacing.large)
        }
    }

    @ViewBuilder
    private func spreadCard(_ item: Item, rank: Int?) -> some View {
        let keepsake = ItemKeepsake(item: item, collection: collection, rank: rank)
        if hasRiffle {
            Button {
                front = riffleIndex.index(of: item) ?? 0
                setSpread(false)
            } label: {
                keepsake
            }
            .buttonStyle(.plain)
            .accessibilityHint("Back to the riffle at this card")
        } else {
            // Tap a keepsake for the thing's own page.
            NavigationLink {
                ItemDetailScreen(item: item)
            } label: {
                keepsake
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private var pinch: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                if !isSpread, value.magnification < 0.8 {
                    setSpread(true)
                } else if isSpread, value.magnification > 1.25 {
                    setSpread(false)
                }
            }
    }

    private func setSpread(_ spread: Bool) {
        withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) {
            isSpread = spread
        }
    }

    private func liftOut(_ item: Item) {
        lifts += 1
        lifted = item
    }

    /// Pushes the drawer back into the cabinet with a clunk.
    private func shut() {
        clunks += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            dismiss()
        }
    }
}
