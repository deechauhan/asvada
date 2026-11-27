import DesignSystem
import Geo
import Model
import SwiftUI

/// An opened drawer. Its keepsakes stand on end in the riffle (#156): thumb through them, tap a
/// tab or the rail to jump, tap the front one to lift it out. Pinch, or tap Spread, to tip them
/// out into the drawer's spread (#44): The Menu for ranked drawers, the Ticket box for logs, the
/// Passport for checklists and the Pinboard for the rest, sorted and filtered from the toolbar.
/// Tapping a card there goes back to the riffle at that card. Countries keeps its stamp pad above
/// its passport, and at the largest text sizes (AX3 and up) every drawer opens straight into its
/// spread. The toolbar customises, shares, re-orders and adds to the drawer.
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
    /// How the spread is sorted and filtered.
    @State private var options = SpreadOptions()
    @Namespace private var cardZoom
    /// Cards morph between the riffle and the spread.
    @Namespace private var morph

    /// Opens the drawer with its riffle at `startItem`'s card (from a lucky dip), or at the front.
    init(collection: ExperienceCollection, startItem: Item? = nil) {
        self.collection = collection
        let start = startItem.flatMap {
            RiffleIndex.make(items: collection.items ?? [], mode: collection.ratingMode).index(of: $0)
        }
        _front = State(initialValue: start ?? 0)
    }

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
                    morph: morph,
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
            if showsSpread, !items.isEmpty {
                spreadMenu
            }
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

    private var spreadKind: SpreadKind {
        SpreadKind(mode: collection.ratingMode)
    }

    /// Each item's place in the drawer's own order, for The Menu's numbers whatever the sort.
    private var ranks: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset + 1) })
    }

    private var spreadItems: [Item] {
        options.apply(to: collection.items ?? [], mode: collection.ratingMode)
    }

    /// Every keepsake at once, laid out for the drawer's mode. In a drawer with a riffle, tapping
    /// one goes back to the riffle at that card; otherwise it opens the thing's page.
    private var spread: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.large) {
                // Countries is a checklist against the world: its progress and stamp pad lead.
                if collection.kind == .countries {
                    PassportPanel(collection: collection)
                }
                if items.isEmpty {
                    if collection.kind != .countries {
                        VStack(spacing: Spacing.medium) {
                            GhostSlip(kind: collection.kind)
                            Text("Nothing savoured yet. Hold Savour something to draw your first.")
                                .font(.system(.body, design: .serif).italic())
                                .foregroundStyle(Palette.textSecondary.color)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.xl)
                    }
                } else if spreadItems.isEmpty {
                    VStack(spacing: Spacing.small) {
                        Text("Nothing matches")
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(Palette.textSecondary.color)
                        Button("Show everything") { options = SpreadOptions(sort: options.sort) }
                            .accessibilityIdentifier("clearSpreadFilters")
                    }
                    .padding(.top, Spacing.xl)
                } else {
                    DrawerSpread(
                        collection: collection,
                        items: spreadItems,
                        kind: spreadKind,
                        ranks: ranks,
                        morph: morph,
                        pick: pick,
                        reorder: collection.ratingMode == .ranked ? { isReordering = true } : nil,
                    )
                }
            }
            .padding(Spacing.large)
        }
    }

    /// A card tapped in the spread: back to the riffle at that card, or its page without one.
    private func pick(_ item: Item) {
        if hasRiffle {
            front = riffleIndex.index(of: item) ?? 0
            setSpread(false)
        } else {
            liftOut(item)
        }
    }

    /// Sort and filter for the spread: by date, rating or name, and to one year or country.
    @ViewBuilder
    private var spreadMenu: some View {
        let all = collection.items ?? []
        let years = SpreadOptions.years(in: all)
        let countries = collection.kind == .countries ? [] : SpreadOptions.countries(in: all)
        Menu {
            Picker("Sort", selection: $options.sort) {
                ForEach(SpreadOptions.Sort.allCases) { sort in
                    Text(sort == .drawer && collection.ratingMode == .ranked ? "Best first" : sort.title).tag(sort)
                }
            }
            if years.count > 1 {
                Picker("Year", selection: $options.year) {
                    Text("Every year").tag(Int?.none)
                    ForEach(years, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                }
            }
            if countries.count > 1 {
                Picker("Country", selection: $options.country) {
                    Text("Everywhere").tag(String?.none)
                    ForEach(countries) { Text($0.name).tag(String?.some($0.code)) }
                }
            }
        } label: {
            Label(
                "Sort and filter",
                systemImage: options.isFiltered
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle",
            )
        }
        .accessibilityIdentifier("spreadOptions")
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
