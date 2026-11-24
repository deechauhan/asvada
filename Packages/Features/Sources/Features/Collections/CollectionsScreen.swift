import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Collections: the turning cabinet by default (one drawer big and centred on a revolving column,
/// docs/design/INTERACTION.md §3), or the whole chest of drawers two to a row ("All drawers").
/// In the chest, "Edit" makes the drawers jiggle: drag one onto another to reorder, or tap its
/// badge to put it away. Put-away collections sit below the chest and can be taken out again.
/// Long-press a drawer to customise, share or put it away.
struct CollectionsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)])
    private var collections: [ExperienceCollection]

    @State private var isCreating = false
    @State private var isArranging = false
    @State private var editing: ExperienceCollection?
    @State private var sharing: ExperienceCollection?
    @State private var opened: ExperienceCollection?
    /// The view the owner chose this session; `nil` follows the default for the text size.
    @State private var chestChosen: Bool?
    @AppStorage("cabinet.front") private var frontID = ""
    @Namespace private var drawerZoom

    private var visible: [ExperienceCollection] {
        collections.filter { !$0.isHidden }
    }

    private var hidden: [ExperienceCollection] {
        collections.filter(\.isHidden)
    }

    private var repository: Repository {
        Repository(context: context)
    }

    /// Drawers move with paper physics; under Reduce Motion they crossfade.
    private var settle: Animation {
        Motion.animation(Motion.settle, reduceMotion: reduceMotion)
    }

    /// The chest is the default at the largest text sizes (AX3 and up), where a 3D drum would
    /// crowd the labels; everyone else starts at the cabinet.
    private var showsChest: Bool {
        chestChosen ?? (typeSize >= .accessibility3)
    }

    var body: some View {
        NavigationStack {
            Group {
                if showsChest {
                    chest
                } else {
                    cabinet
                }
            }
            .background(Palette.background.color)
            .overlay {
                if collections.isEmpty {
                    ContentUnavailableView("No collections", systemImage: AppTab.collections.symbol)
                }
            }
            .navigationTitle(AppTab.collections.title)
            .toolbar { toolbar }
            .navigationDestination(item: $opened) { collection in
                OpenDrawer(collection: collection)
                    .zoomTransition(id: collection.id, in: drawerZoom)
            }
            .sheet(isPresented: $isCreating) {
                CollectionEditor(mode: .create)
            }
            // Clear the item explicitly on dismiss: customising the same drawer twice in a row
            // must change `editing`, or the second sheet never presents.
            .sheet(item: $editing, onDismiss: clearEditing) { collection in
                CollectionEditor(mode: .edit(collection))
            }
            .sheet(item: $sharing) { collection in
                if let content = ShareContent(collection: collection) {
                    ShareCardSheet(collection: collection, content: content)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("New collection", systemImage: "plus") {
                isCreating = true
            }
            .accessibilityIdentifier("newCollectionButton")
        }
        if showsChest {
            ToolbarItem(placement: .primaryAction) {
                Button(isArranging ? "Done" : "Edit") {
                    withAnimation(settle) { isArranging.toggle() }
                }
                .fontWeight(isArranging ? .semibold : .regular)
                .accessibilityIdentifier("arrangeButton")
            }
            ToolbarItem(placement: .navigation) {
                Button("Cabinet", systemImage: "cabinet") {
                    withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) {
                        isArranging = false
                        chestChosen = false
                    }
                }
                .accessibilityIdentifier("cabinetButton")
            }
        } else {
            ToolbarItem(placement: .navigation) {
                Button("All drawers", systemImage: "square.grid.2x2") {
                    withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) {
                        chestChosen = true
                    }
                }
                .accessibilityIdentifier("allDrawersButton")
            }
        }
    }

    // MARK: - The turning cabinet

    private var cabinet: some View {
        VStack(spacing: Spacing.medium) {
            Spacer(minLength: 0)
            TurningCabinet(
                collections: visible,
                frontID: $frontID,
                actions: cabinetActions,
                namespace: drawerZoom,
            )
            Text("Swipe to turn · pull a drawer toward you to open it")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .multilineTextAlignment(.center)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.bottom, Spacing.xl)
        .transition(.opacity)
    }

    private var cabinetActions: CabinetActions {
        CabinetActions(
            open: { opened = $0 },
            create: { isCreating = true },
            customise: { collection in afterMenuCloses { editing = collection } },
            share: { collection in afterMenuCloses { sharing = collection } },
            hide: { setHidden(true, $0) },
            move: { collection, slot in
                guard let index = visible.firstIndex(where: { $0.id == collection.id }) else { return }
                step(collection, by: slot - index)
            },
        )
    }

    // MARK: - The chest

    private var chest: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Not lazy: a chest holds a handful of drawers, and every drawer should exist
                // for VoiceOver and UI tests even when scrolled off screen.
                Grid(horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.large) {
                    ForEach(Array(cabinetRows.enumerated()), id: \.offset) { _, row in
                        GridRow(alignment: .top) {
                            ForEach(row) { slot in
                                cell(for: slot)
                            }
                            if row.count == 1 {
                                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
                if !hidden.isEmpty {
                    hiddenSection
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
            .animation(settle, value: visible.map(\.id))
            .animation(settle, value: isArranging)
        }
        .transition(.opacity)
    }

    // MARK: - Chest cells

    /// A grid cell: a collection's drawer, or the blank "new collection" tag at the end.
    private enum Slot: Identifiable {
        case drawer(ExperienceCollection)
        case new

        var id: String {
            switch self {
            case let .drawer(collection): collection.id.uuidString
            case .new: "new"
            }
        }
    }

    private var cabinetRows: [[Slot]] {
        let slots = visible.map(Slot.drawer) + (isArranging ? [] : [.new])
        return stride(from: 0, to: slots.count, by: 2).map { Array(slots[$0 ..< min($0 + 2, slots.count)]) }
    }

    @ViewBuilder
    private func cell(for slot: Slot) -> some View {
        switch slot {
        case let .drawer(collection):
            drawer(collection)
        case .new:
            NewCollectionTile { isCreating = true }
        }
    }

    private func drawer(_ collection: ExperienceCollection) -> some View {
        CabinetDrawer(collection: collection, isArranging: isArranging) {
            setHidden(true, collection)
        }
        .onTapGesture {
            // Tapping a drawer in the chest turns the cabinet to it.
            guard !isArranging else { return }
            frontID = collection.id.uuidString
            withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) {
                chestChosen = false
            }
        }
        .draggable(collection.id.uuidString) {
            MiniDrawerPreview(collection: collection)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            return move(id, onto: collection)
        }
        // A long press shows this menu; moving the finger instead lifts the drawer to drag.
        .contextMenu {
            Button("Customise", systemImage: "slider.horizontal.3") {
                afterMenuCloses { editing = collection }
            }
            // Only filled drawers have something to share.
            if ShareContent(collection: collection) != nil {
                Button("Share", systemImage: "square.and.arrow.up") {
                    afterMenuCloses { sharing = collection }
                }
            }
            Button("Hide", systemImage: "eye.slash") {
                setHidden(true, collection)
            }
        }
        .accessibilityAction(named: "Customise") { editing = collection }
        .accessibilityAction(named: "Share") {
            if ShareContent(collection: collection) != nil {
                sharing = collection
            }
        }
        .accessibilityAction(named: "Move earlier") { step(collection, by: -1) }
        .accessibilityAction(named: "Move later") { step(collection, by: 1) }
        .accessibilityAction(named: "Hide") { setHidden(true, collection) }
    }

    private var hiddenSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Hidden")
                .typeToken(.headline)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityAddTraits(.isHeader)
            ForEach(hidden) { collection in
                HiddenCollectionRow(collection: collection) {
                    setHidden(false, collection)
                }
            }
        }
    }

    // MARK: - Actions

    /// Drops the dragged drawer into the slot of the drawer it was dropped on.
    private func move(_ draggedID: String, onto target: ExperienceCollection) -> Bool {
        let source = visible.firstIndex(where: { $0.id.uuidString == draggedID })
        let slot = visible.firstIndex(where: { $0.id == target.id })
        guard let source, let slot, slot != source else { return false }
        let destination = CabinetOrder.destination(moving: source, onto: slot)
        withAnimation(settle) {
            repository.reorder(visible, moving: IndexSet(integer: source), to: destination)
        }
        save()
        return true
    }

    /// VoiceOver reordering: one place earlier or later.
    private func step(_ collection: ExperienceCollection, by offset: Int) {
        guard let source = visible.firstIndex(where: { $0.id == collection.id }) else { return }
        let slot = source + offset
        guard visible.indices.contains(slot) else { return }
        let destination = CabinetOrder.destination(moving: source, onto: slot)
        withAnimation(settle) {
            repository.reorder(visible, moving: IndexSet(integer: source), to: destination)
        }
        save()
    }

    /// Runs `present` once a context menu has finished closing. Presenting a sheet straight from a
    /// menu action races the menu's dismissal, and UIKit then drops the sheet (seen as a second
    /// Customise that did nothing).
    private func afterMenuCloses(_ present: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: Self.menuDismissal)
            present()
        }
    }

    /// Long enough for the context menu's closing animation.
    static let menuDismissal = Duration.milliseconds(400)

    private func clearEditing() {
        editing = nil
    }

    private func setHidden(_ isHidden: Bool, _ collection: ExperienceCollection) {
        withAnimation(settle) {
            repository.setHidden(isHidden, for: collection)
        }
        save()
    }

    private func save() {
        do {
            try repository.save()
        } catch {
            assertionFailure("Saving collections failed: \(error)")
        }
    }
}

/// Reordering arithmetic for drag-onto-a-drawer.
enum CabinetOrder {
    /// The `onMove`-style destination for moving the item at `source` into the slot of the item at
    /// `target`. `onMove` counts the destination before removal, so moving later needs one more.
    static func destination(moving source: Int, onto target: Int) -> Int {
        target > source ? target + 1 : target
    }
}

/// A hidden collection: dimmed, with a button to bring it back into the cabinet.
private struct HiddenCollectionRow: View {
    let collection: ExperienceCollection
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: collection.icon)
                .foregroundStyle(collection.accent.token.color)
                .frame(width: 32, height: 32)
                .background(collection.accent.token.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityHidden(true)
            Text(collection.name)
                .typeToken(.body)
                .foregroundStyle(Palette.textPrimary.color)
            Spacer(minLength: 0)
            Button("Show", action: onShow)
                .buttonStyle(.bordered)
                .tint(Palette.brand.color)
                .accessibilityLabel("Show \(collection.name)")
                .accessibilityIdentifier("showCollection-\(collection.name)")
        }
        .padding(Spacing.small)
        .background(Palette.surface.color.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.medium))
        .opacity(0.75)
    }
}

/// What follows the finger while a drawer is dragged.
private struct MiniDrawerPreview: View {
    let collection: ExperienceCollection

    var body: some View {
        Label(collection.name, systemImage: collection.icon)
            .typeToken(.headline)
            .foregroundStyle(collection.accent.token.color)
            .padding(Spacing.medium)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

#Preview {
    CollectionsScreen()
        .modelContainer(PreviewData.container)
}
