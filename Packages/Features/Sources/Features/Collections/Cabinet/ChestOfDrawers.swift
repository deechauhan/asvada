import DesignSystem
import Model
import SwiftUI

/// The whole chest of drawers (INTERACTION.md §3 step 5): every drawer two to a row, reached by
/// pinching the cabinet or "All drawers". Tap a drawer and the cabinet turns to it. Hold a drawer
/// to lift it, carry it onto another drawer's place to reorder (the drawer underneath makes room),
/// or drop it on the storeroom shelf to put it away. Put-away drawers wait on the shelf, each
/// with "Take out". A plain hold still opens the drawer's menu (Customise, Share, Put away).
struct ChestOfDrawers: View {
    let drawers: [ExperienceCollection]
    let putAway: [ExperienceCollection]
    var actions: CabinetActions
    /// Moves the dragged drawer (by id) into `target`'s place; false if nothing moved.
    var reorder: (String, ExperienceCollection) -> Bool
    /// Brings a put-away drawer back into the cabinet.
    var takeOut: (ExperienceCollection) -> Void
    /// Turns the cabinet to a drawer and goes back to it.
    var turnTo: (ExperienceCollection) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The drawer a carried drawer is hovering over: it shuffles aside to make room.
    @State private var makingRoom: UUID?

    private var settle: Animation {
        Motion.animation(Motion.settle, reduceMotion: reduceMotion)
    }

    private var rows: [[ExperienceCollection?]] {
        // `nil` is the blank "new collection" tag at the end.
        let slots: [ExperienceCollection?] = drawers + [nil]
        return stride(from: 0, to: slots.count, by: 2).map { Array(slots[$0 ..< min($0 + 2, slots.count)]) }
    }

    var body: some View {
        ScrollView {
            // Not lazy: a chest holds a handful of drawers, and every drawer should exist for
            // VoiceOver and UI tests even when scrolled off screen.
            Grid(horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.large) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow(alignment: .top) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                            cell(slot)
                        }
                        if row.count == 1 {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
            .animation(settle, value: drawers.map(\.id))
        }
        .safeAreaInset(edge: .bottom) {
            Storeroom(drawers: putAway, takeOut: takeOut, putAway: putAwayDropped)
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.small)
        }
    }

    @ViewBuilder
    private func cell(_ slot: ExperienceCollection?) -> some View {
        if let collection = slot {
            drawer(collection)
        } else {
            NewCollectionTile(action: actions.create)
        }
    }

    private func drawer(_ collection: ExperienceCollection) -> some View {
        let isMakingRoom = makingRoom == collection.id
        return CabinetDrawer(collection: collection)
            .scaleEffect(isMakingRoom ? 0.92 : 1)
            .offset(y: isMakingRoom ? 10 : 0)
            .animation(settle, value: isMakingRoom)
            .onTapGesture { turnTo(collection) }
            // Holding lifts the drawer (the system's lift and haptic); moving carries it.
            .draggable(collection.id.uuidString) {
                MiniDrawerPreview(collection: collection)
            }
            .dropDestination(for: String.self) { ids, _ in
                makingRoom = nil
                guard let id = ids.first else { return false }
                return reorder(id, collection)
            } isTargeted: { targeted in
                if targeted {
                    makingRoom = collection.id
                } else if makingRoom == collection.id {
                    makingRoom = nil
                }
            }
            // A hold without moving shows this menu instead.
            .contextMenu {
                Button("Customise", systemImage: "slider.horizontal.3") { actions.customise(collection) }
                // Only filled drawers have something to share.
                if ShareContent(collection: collection) != nil {
                    Button("Share", systemImage: "square.and.arrow.up") { actions.share(collection) }
                }
                Button("Put away", systemImage: "archivebox") { actions.hide(collection) }
            }
            .modifier(ChestDrawerActions(
                collection: collection,
                index: drawers.firstIndex(of: collection) ?? 0,
                actions: actions,
            ))
    }

    /// A drawer dropped on the storeroom shelf is put away.
    private func putAwayDropped(_ id: String) -> Bool {
        guard let collection = drawers.first(where: { $0.id.uuidString == id }) else { return false }
        actions.hide(collection)
        return true
    }
}

/// The VoiceOver actions on a drawer in the chest, the same as in the cabinet.
private struct ChestDrawerActions: ViewModifier {
    let collection: ExperienceCollection
    let index: Int
    let actions: CabinetActions

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: "Customise", customise)
            .accessibilityAction(named: "Share", share)
            .accessibilityAction(named: "Move earlier", moveEarlier)
            .accessibilityAction(named: "Move later", moveLater)
            .accessibilityAction(named: "Put away", putAway)
    }

    private func customise() {
        actions.customise(collection)
    }

    private func share() {
        if ShareContent(collection: collection) != nil {
            actions.share(collection)
        }
    }

    private func moveEarlier() {
        actions.move(collection, index - 1)
    }

    private func moveLater() {
        actions.move(collection, index + 1)
    }

    private func putAway() {
        actions.hide(collection)
    }
}

/// The storeroom shelf docked above the savour pill: put-away drawers wait here, each with
/// "Take out"; dropping a carried drawer on the shelf puts it away.
private struct Storeroom: View {
    let drawers: [ExperienceCollection]
    let takeOut: (ExperienceCollection) -> Void
    let putAway: (String) -> Bool

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Storeroom")
                .typeToken(.headline)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityAddTraits(.isHeader)
            if drawers.isEmpty {
                Text("Drop a drawer here to put it away")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.small) {
                        ForEach(drawers) { collection in
                            StoredDrawer(collection: collection) { takeOut(collection) }
                        }
                    }
                }
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color.opacity(isTargeted ? 1 : 0.85), in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder(
                    isTargeted ? Palette.brand.color : Palette.separator.color,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [5, 4]),
                ),
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            return putAway(id)
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storeroom")
    }
}

/// A put-away drawer on the storeroom shelf, with its "Take out" button.
private struct StoredDrawer: View {
    let collection: ExperienceCollection
    let takeOut: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: collection.icon)
                .foregroundStyle(collection.accent.token.color)
                .accessibilityHidden(true)
            Text(collection.name)
                .typeToken(.body)
                .foregroundStyle(Palette.textPrimary.color)
            Button("Take out", action: takeOut)
                .buttonStyle(.bordered)
                .tint(Palette.brand.color)
                .accessibilityLabel("Take out \(collection.name)")
                .accessibilityIdentifier("showCollection-\(collection.name)")
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.small)
        .background(Palette.background.color, in: Capsule())
    }
}

/// What follows the finger while a drawer is carried.
struct MiniDrawerPreview: View {
    let collection: ExperienceCollection

    var body: some View {
        Label(collection.name, systemImage: collection.icon)
            .typeToken(.headline)
            .foregroundStyle(collection.accent.token.color)
            .padding(Spacing.medium)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

/// Pinch-to-morph between the cabinet and the chest: how far a pinch has gone, 0...1.
enum ChestMorph {
    /// Progress for a pinch of `magnification` (1 = no change). Toward the chest the fingers
    /// close (magnification below 1); back to the cabinet they open.
    static func progress(magnification: Double, towardChest: Bool) -> Double {
        let travel = towardChest ? (1 - magnification) / 0.5 : (magnification - 1) / 0.6
        return min(max(travel, 0), 1)
    }

    /// Whether a released pinch commits (past halfway).
    static func commits(_ progress: Double) -> Bool {
        progress > 0.5
    }
}
