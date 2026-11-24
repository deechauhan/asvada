import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Collections: the turning cabinet by default (one drawer big and centred on a revolving column,
/// docs/design/INTERACTION.md §3), or the whole chest of drawers two to a row. Pinch the cabinet
/// (or tap "All drawers") for the chest; pinch out (or "Done") to go back. In the chest, carry a
/// drawer to reorder it or drop it in the storeroom to put it away.
struct CollectionsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)])
    private var collections: [ExperienceCollection]

    @State private var isCreating = false
    @State private var editing: ExperienceCollection?
    @State private var sharing: ExperienceCollection?
    @State private var opened: ExperienceCollection?
    /// Set by a sheet when it appears, so a sheet requested from a context menu can be retried.
    @State private var sheetAppeared = false
    /// The view the owner chose this session; `nil` follows the default for the text size.
    @State private var chestChosen: Bool?
    @AppStorage("cabinet.front") private var frontID = ""
    /// How far a pinch has carried the view toward the other one, 0...1.
    @State private var pinch = 0.0
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
            // A pinch scrubs toward the other view: the current one shrinks (or swells) and fades.
            .scaleEffect(1 + (showsChest ? 0.12 : -0.22) * pinch)
            .opacity(1 - 0.55 * pinch)
            .simultaneousGesture(pinchGesture)
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
                    .onAppear { sheetAppeared = true }
            }
            .sheet(item: $sharing) { collection in
                if let content = ShareContent(collection: collection) {
                    ShareCardSheet(collection: collection, content: content)
                        .onAppear { sheetAppeared = true }
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
            ToolbarItem(placement: .navigation) {
                Button("Done") {
                    morph(toChest: false)
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("cabinetButton")
            }
        } else {
            ToolbarItem(placement: .navigation) {
                Button("All drawers", systemImage: "square.grid.2x2") {
                    morph(toChest: true)
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
            customise: { afterMenuCloses({ editing = $0 }, $0) },
            share: { afterMenuCloses({ sharing = $0 }, $0) },
            hide: { setHidden(true, $0) },
            move: { collection, slot in
                guard let index = visible.firstIndex(where: { $0.id == collection.id }) else { return }
                step(collection, by: slot - index)
            },
        )
    }

    // MARK: - The chest

    private var chest: some View {
        ChestOfDrawers(
            drawers: visible,
            putAway: hidden,
            actions: cabinetActions,
            reorder: { move($0, onto: $1) },
            takeOut: { setHidden(false, $0) },
            turnTo: { collection in
                frontID = collection.id.uuidString
                morph(toChest: false)
            },
        )
        .transition(.opacity)
    }

    // MARK: - Pinch

    /// Fingers together on the cabinet heads for the chest; apart on the chest heads back.
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinch = ChestMorph.progress(magnification: value.magnification, towardChest: !showsChest)
            }
            .onEnded { _ in
                if ChestMorph.commits(pinch) {
                    morph(toChest: !showsChest)
                } else {
                    withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) { pinch = 0 }
                }
            }
    }

    /// Switches between the cabinet and the chest with the morph spring.
    private func morph(toChest: Bool) {
        withAnimation(Motion.animation(Motion.morph, reduceMotion: reduceMotion)) {
            chestChosen = toChest
            pinch = 0
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

    /// Shows `collection` in a sheet (through `show`) once a context menu has finished closing.
    /// Presenting straight from a menu action races the menu's dismissal and UIKit drops the
    /// sheet; on a slow device even a fixed wait isn't always enough. So the sheet reports when it
    /// appears, and until it has, the request is cleared and made again a little later.
    private func afterMenuCloses(
        _ show: @escaping @MainActor (ExperienceCollection?) -> Void,
        _ collection: ExperienceCollection,
    ) {
        sheetAppeared = false
        Task { @MainActor in
            for wait in Self.menuDismissalRetries {
                try? await Task.sleep(for: wait)
                guard !sheetAppeared else { return }
                // A cleared request has to reach SwiftUI before the new one, or nothing changes.
                show(nil)
                try? await Task.sleep(for: .milliseconds(50))
                show(collection)
            }
        }
    }

    /// The context menu's closing animation, then two later tries if the sheet was dropped.
    static let menuDismissalRetries: [Duration] = [.milliseconds(400), .milliseconds(500), .milliseconds(1000)]

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

#Preview {
    CollectionsScreen()
        .modelContainer(PreviewData.container)
}
