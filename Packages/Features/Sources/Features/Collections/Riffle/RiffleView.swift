import DesignSystem
import Model
import SwiftUI

/// The riffle (INTERACTION.md §4b, #156): a drawer's keepsakes stood on end like cards in a
/// library catalogue drawer. Thumb down to flip the front card toward you and bring up the next,
/// one detent per card; the cards behind step up so their index tabs show. Tap a tab or scrub the
/// rail to jump; tap the front card to lift it out; tap the drawer front to shut it.
///
/// Built as a pager over `RifflePager` (ADR-0004's fallback to the drum's physics): only the
/// cards near the front are in the hierarchy, so a drawer of a thousand films costs the same as
/// one of ten. VoiceOver meets the front cards as buttons, with Next and Previous card actions
/// and the adjustable rail; Reduce Motion slides the cards instead of turning them.
struct RiffleView: View {
    let collection: ExperienceCollection
    let index: RiffleIndex
    /// The card at the front, kept by the drawer so the spread can come back to it.
    @Binding var front: Int
    let namespace: Namespace.ID
    var lift: (Item) -> Void
    var shut: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pager = RifflePager(count: 0)
    @State private var dragStart: Double?
    @State private var lastMove: Date?
    @State private var detents = 0
    @State private var width = 0.0

    /// The card's width: as wide as fits beside the rail, up to 320 pt.
    private var cardWidth: Double {
        min(max(width - RiffleRail.width - Spacing.large * 2, 200), 320)
    }

    var body: some View {
        VStack(spacing: Spacing.small) {
            Text("Thumb down to flip · tap the front one to lift it out")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: Spacing.small) {
                stack
                RiffleRail(marks: index.marks, front: pager.frontIndex) { jump(to: $0) }
            }
            .padding(.horizontal, Spacing.large)
            DrawerLip(collection: collection, shut: shut)
                .padding(.horizontal, Spacing.medium)
        }
        .padding(.bottom, Spacing.medium)
        .onGeometryChange(for: Double.self, of: { Double($0.size.width) }, action: { width = $0 })
        .detentHaptic(trigger: detents)
        .onAppear(perform: sync)
        .onChange(of: index.cards.map(\.id)) { _, _ in sync() }
    }

    // MARK: - The stack

    private var stack: some View {
        ZStack(alignment: .bottom) {
            ForEach(pager.visibleIndices(), id: \.self) { cardIndex in
                card(at: cardIndex)
            }
        }
        // Room for the cards behind to step up with their tabs.
        .frame(
            maxWidth: .infinity,
            minHeight: cardWidth * RiffleCardView.aspect + RiffleCardGeometry.step * 5,
            alignment: .bottom,
        )
        .contentShape(Rectangle())
        .gesture(drag)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("riffle")
    }

    private func card(at cardIndex: Int) -> some View {
        let card = index.cards[cardIndex]
        let offset = pager.offset(of: cardIndex)
        let isFront = cardIndex == pager.frontIndex
        return RiffleCardView(
            card: card,
            collection: collection,
            slot: RiffleIndex.tabSlot(for: cardIndex),
            isFront: isFront,
            width: cardWidth,
        )
        .zoomSource(id: card.id, in: namespace)
        .onTapGesture { tap(cardIndex) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isFront ? "Lifts it out" : "Brings it to the front")
        .accessibilityAction { tap(cardIndex) }
        .accessibilityAction(named: "Next card") { jump(to: pager.frontIndex + 1) }
        .accessibilityAction(named: "Previous card") { jump(to: pager.frontIndex - 1) }
        // Front first, then the cards behind in order; flipped cards are gone.
        .accessibilitySortPriority(-offset)
        .accessibilityHidden(offset < -0.5)
        // Last, so its stacking order is the stack's own.
        .modifier(RiffleFace(position: pager.position, index: cardIndex, reduceMotion: reduceMotion))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = pager.position
                }
                lastMove = value.time
                let before = pager.frontIndex
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pager.position = pager.position(dragging: value.translation.height, from: dragStart ?? pager.position)
                }
                if pager.frontIndex != before {
                    detents += 1
                }
            }
            .onEnded { value in
                let rest = lastMove.map { value.time.timeIntervalSince($0) } ?? 0
                let velocity = CabinetDrum.releaseVelocity(value.velocity.height, restedFor: rest)
                settle(to: pager.restingPosition(afterReleaseAt: velocity))
                dragStart = nil
                lastMove = nil
            }
    }

    // MARK: - Moving

    private func tap(_ cardIndex: Int) {
        guard index.cards.indices.contains(cardIndex) else { return }
        if cardIndex == pager.frontIndex {
            if let item = index.cards[cardIndex].item {
                lift(item)
            } else {
                // A guide card has nothing to lift: tapping it moves on to its first keepsake.
                jump(to: cardIndex + 1)
            }
        } else {
            jump(to: cardIndex)
        }
    }

    private func jump(to cardIndex: Int) {
        guard index.cards.indices.contains(cardIndex) else { return }
        settle(to: Double(cardIndex))
    }

    /// Springs the riffle to `target`, clicking once per card it passes.
    private func settle(to target: Double) {
        let passed = Int(abs(target - pager.position.rounded()))
        // A short flick clicks as it passes each card; a long jump clicks a few times, not dozens.
        for step in 0 ..< min(passed, 6) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(45 * (step + 1)))
                detents += 1
            }
        }
        withAnimation(Motion.animation(Motion.riffle, reduceMotion: reduceMotion)) {
            pager.position = target
        }
        front = pager.frontIndex
    }

    /// Takes up the drawer's cards, keeping the front card where it was (or where the spread
    /// sent it).
    private func sync() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pager = RifflePager(count: index.cards.count, position: Double(front))
            pager.position = Double(pager.frontIndex)
        }
        front = pager.frontIndex
    }
}

/// Stands one card in the riffle. Animatable in the pager's position, so a spring turns each card
/// over its bottom edge rather than sliding it.
private struct RiffleFace: ViewModifier, Animatable {
    var position: Double
    let index: Int
    let reduceMotion: Bool

    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let offset = Double(index) - position
        let geometry = RiffleCardGeometry(offset: offset, reduceMotion: reduceMotion)
        content
            .rotation3DEffect(
                .degrees(geometry.rotation),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: RiffleCardGeometry.perspective,
            )
            .scaleEffect(geometry.scale, anchor: .bottom)
            .offset(y: geometry.y)
            .opacity(geometry.opacity)
            .zIndex(geometry.zIndex)
            .allowsHitTesting(geometry.isVisible && offset > -0.5)
    }
}
