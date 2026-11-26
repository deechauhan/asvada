import DesignSystem
import Model
import Ranking
import SwiftUI

/// Ranked and new: "Which did you savour more?", halving the ranking each time, at most
/// ⌈log₂(n+1)⌉ picks, with saffron macron steps, *Too close to call* and *Skip* (seal it now and
/// rank it later). Each card shows the thing's latest photo when it has one.
///
/// The duel is played with keepsakes (#119): the card you didn't pick leans away and the next one
/// lands in its place. Once placed, the newcomer flies into the ranked list, the rows around it make
/// room, and "No. n" stamps onto it before the seal. Reduce Motion: no lean or flight, a crossfade.
struct DuelStep: View {
    let newcomer: Item
    let ranked: [Item]
    let onPlaced: (Int) -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var flight
    @State private var insertion: BinaryInsertion
    /// The card leaning away after a pick, and the answer to record once it has.
    @State private var parting: Parting?
    /// Where the newcomer landed: shown with its stamp for a beat, then on to the seal.
    @State private var placed: Int?

    init(newcomer: Item, ranked: [Item], count _: Int, onPlaced: @escaping (Int) -> Void, onSkip: @escaping () -> Void) {
        self.newcomer = newcomer
        self.ranked = ranked
        self.onPlaced = onPlaced
        self.onSkip = onSkip
        _insertion = State(initialValue: BinaryInsertion(count: ranked.count))
    }

    private struct Parting: Equatable {
        let loser: DuelPlacement.Side
        let verdict: Verdict
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            if let placed {
                placement(at: placed)
            } else {
                duel
            }
        }
        .haptic(.stamp, trigger: placed)
        .task(id: parting) { await finishParting() }
        .task(id: placed) { await moveOn() }
    }

    // MARK: The duel

    @ViewBuilder
    private var duel: some View {
        Text(QuickLogFlow.duelQuestion)
            .font(.system(.title3, design: .serif, weight: .semibold))
            .foregroundStyle(Palette.textPrimary.color)
            .accessibilityAddTraits(.isHeader)
        if let index = insertion.comparisonIndex, ranked.indices.contains(index) {
            HStack(spacing: Spacing.medium) {
                card(newcomer, side: .newcomer, id: "duelNew") { pick(.better, loser: .other) }
                    .flies(id: newcomer.id, in: flight, unless: reduceMotion)
                card(ranked[index], side: .other, id: "duelOther") { pick(.worse, loser: .newcomer) }
                    .id(ranked[index].id)
                    .transition(.asymmetric(insertion: Motion.landing(reduceMotion: reduceMotion), removal: .opacity))
            }
            .allowsHitTesting(parting == nil)
            .haptic(.pick, trigger: insertion.comparisonsMade)
            MacronSteps(
                done: insertion.comparisonsMade,
                total: insertion.comparisonsMade + insertion.remainingComparisonsAtMost,
            )
            HStack {
                if insertion.canUndo {
                    Button("Undo") { animated { insertion.undo() } }
                        .accessibilityIdentifier("duelUndo")
                }
                Spacer()
                Button("Skip", action: onSkip)
                    .accessibilityHint("Seal it now without ranking it yet")
                    .accessibilityIdentifier("duelSkip")
                // Ties go just below the item shown; neither card loses.
                Button("Too close to call") { animated { record(.worse) } }
                    .padding(.leading, Spacing.medium)
                    .accessibilityIdentifier("duelTie")
            }
            .typeToken(.callout)
            .disabled(parting != nil)
        }
    }

    private func card(_ item: Item, side: DuelPlacement.Side, id: String, action: @escaping () -> Void) -> some View {
        let isLeaving = parting?.loser == side
        let isKept = parting != nil && !isLeaving
        return Button(action: action) {
            VStack(spacing: Spacing.small) {
                if let data = item.latestThumbnailData {
                    PhotoThumbnail(id: item.id.uuidString, data: data).image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                        .accessibilityHidden(true)
                }
                Text(item.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Palette.textPrimary.color)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(Spacing.small)
            .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).strokeBorder(Palette.separator.color))
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(isLeaving ? DuelPlacement.lean(side) : 0), anchor: .bottom)
        .offset(x: isLeaving ? DuelPlacement.drift(side) : 0, y: isLeaving ? 10 : 0)
        .opacity(isLeaving ? 0.35 : 1)
        .scaleEffect(isKept ? 1.04 : 1)
        .accessibilityLabel("\(item.name) was better")
        .accessibilityIdentifier(id)
    }

    /// The loser leans away first (straight on under Reduce Motion), then the answer counts.
    private func pick(_ verdict: Verdict, loser: DuelPlacement.Side) {
        guard parting == nil else { return }
        guard !reduceMotion else {
            animated { record(verdict) }
            return
        }
        withAnimation(.easeIn(duration: DuelPlacement.partingSeconds)) {
            parting = Parting(loser: loser, verdict: verdict)
        }
    }

    private func finishParting() async {
        guard let parting else { return }
        try? await Task.sleep(for: .seconds(DuelPlacement.partingSeconds))
        guard !Task.isCancelled else { return }
        animated {
            self.parting = nil
            record(parting.verdict)
        }
    }

    private func record(_ verdict: Verdict) {
        insertion.record(verdict)
        placed = insertion.position
    }

    private func animated(_ change: () -> Void) {
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion), change)
    }

    // MARK: Placed

    /// The ranked rows around the newcomer, with it in its new place and "No. n" stamped on it.
    private func placement(at position: Int) -> some View {
        let order = DuelPlacement.inserting(newcomer, into: ranked, at: position)
        let window = DuelPlacement.window(count: ranked.count, position: position)
        return VStack(spacing: Spacing.xs) {
            ForEach(window, id: \.self) { index in
                let item = order[index]
                if item.id == newcomer.id {
                    PlacedRow(name: item.name, rank: index + 1)
                        .flies(id: newcomer.id, in: flight, unless: reduceMotion)
                } else {
                    rankedRow(item.name, rank: index + 1)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("duelPlaced")
    }

    private func rankedRow(_ name: String, rank: Int) -> some View {
        HStack(spacing: Spacing.medium) {
            Text("\(rank)")
                .font(.system(.callout, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary.color)
                .frame(width: 32, alignment: .trailing)
            Text(name)
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No. \(rank), \(name)")
    }

    /// Holds "No. n" long enough to read, then seals.
    private func moveOn() async {
        guard let placed else { return }
        AccessibilityNotification.Announcement(DuelPlacement.spoken(placed, name: newcomer.name)).post()
        try? await Task.sleep(for: .seconds(DuelPlacement.holdSeconds(reduceMotion: reduceMotion)))
        guard !Task.isCancelled else { return }
        onPlaced(placed)
    }
}

/// The newcomer's row once placed: its card, now in the list, with "No. n" thunked onto it.
private struct PlacedRow: View {
    let name: String
    let rank: Int
    @State private var landed = false

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(name)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
                .lineLimit(2)
            Spacer(minLength: Spacing.small)
            Text("No. \(rank)")
                .font(.system(.title3, design: .serif, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.brand.color)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxs)
                .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Palette.brand.color, lineWidth: 2))
                .paperTilt(-6)
                .thunk(trigger: landed)
                .accessibilityIdentifier("duelStamp")
        }
        .padding(Spacing.medium)
        .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).strokeBorder(Palette.brand.color, lineWidth: 1.5))
        .onAppear { landed = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No. \(rank), \(name)")
    }
}

/// The duel's progress: one saffron macron bar per question.
private struct MacronSteps: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0 ..< max(total, 1), id: \.self) { step in
                Capsule()
                    .fill(step < done ? Palette.saffron.color : Palette.separator.color)
                    .frame(width: 22, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(min(done + 1, max(total, 1))) of at most \(max(total, 1))")
    }
}

private extension View {
    /// The newcomer's card flying into its row, or a plain crossfade under Reduce Motion.
    @ViewBuilder
    func flies(id: UUID, in namespace: Namespace.ID, unless reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

/// The duel's choreography, kept apart from the view so it can be tested.
enum DuelPlacement {
    /// The two cards: the newcomer on the left, the one it's compared with on the right.
    enum Side: Equatable {
        case newcomer
        case other
    }

    /// How long the losing card takes to lean away.
    static let partingSeconds = 0.22
    /// How many ranked rows show around the newcomer once placed.
    static let windowSize = 5

    /// How far the losing card leans, in degrees: away from the other, so left leans left.
    static func lean(_ side: Side) -> Double {
        side == .newcomer ? -12 : 12
    }

    /// How far the losing card drifts sideways as it leans, in points.
    static func drift(_ side: Side) -> Double {
        side == .newcomer ? -28 : 28
    }

    /// How long "No. n" holds before the seal: long enough to read, shorter without motion.
    static func holdSeconds(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.6 : 1.1
    }

    /// `ranked` with `newcomer` placed at `position` (clamped to the list).
    static func inserting<T>(_ newcomer: T, into ranked: [T], at position: Int) -> [T] {
        var order = ranked
        order.insert(newcomer, at: min(max(position, 0), ranked.count))
        return order
    }

    /// Which rows of the new order to show: up to `size`, centred on the newcomer where the list
    /// allows, so No. 1 shows the top and last place shows the bottom.
    static func window(count: Int, position: Int, size: Int = windowSize) -> Range<Int> {
        let total = count + 1
        let shown = min(max(size, 1), total)
        let place = min(max(position, 0), count)
        let start = min(max(place - shown / 2, 0), total - shown)
        return start ..< start + shown
    }

    /// What VoiceOver says once placed: "Tiny Tea Stall is No. 1".
    static func spoken(_ position: Int, name: String) -> String {
        "\(name) is No. \(position + 1)"
    }
}
