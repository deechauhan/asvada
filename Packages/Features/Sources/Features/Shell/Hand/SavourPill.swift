import DesignSystem
import Model
import SwiftUI
import TipKit

/// What the shell needs to draw the hand: whether it's out, which blank the thumb is on, and
/// where the pill is on screen (the hand fans out over it).
struct HandState: Equatable {
    var isShown = false
    var selection: Int?
    var origin: CGPoint = .zero
}

/// The savour pill (INTERACTION.md §5). A tap opens quick-log on the hand laid out as a grid.
/// Holding for 170 ms, or sliding up more than 8 pt, fans the hand of blanks out over the
/// thumb; sliding onto a blank lifts it and letting go draws it. A quick flick draws the same
/// blank before the hand has even appeared, because the blanks never move. Sliding below the
/// pill cancels.
struct SavourPill: View {
    /// The visible collections, in cabinet order (the hand holds the first eight).
    let collections: [ExperienceCollection]
    @Binding var hand: HandState
    let onTap: () -> Void
    let onDraw: (ExperienceCollection) -> Void

    /// How long a press must last before the hand fans out.
    static let holdDelay = Duration.milliseconds(170)
    /// How far up a slide must go to bring the hand out early.
    static let slideToShow: CGFloat = 8
    /// The most a press can move and still count as a tap.
    static let tapSlop: CGFloat = 10

    /// Where the pill is on screen. Kept here, not in the shell's state: writing it upward on
    /// every layout re-rendered the whole tab view, which re-laid out the pill, endlessly.
    @State private var origin: CGPoint = .zero
    @State private var isPressing = false
    @State private var holdTimer: Task<Void, Never>?
    @State private var draws = 0
    private let tip = HoldToDrawTip()

    private var hand8: [ExperienceCollection] {
        Array(collections.prefix(HandLayout.maximumCount))
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("ā")
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.onBrand.color)
                .frame(width: 26, height: 26)
                .background(Palette.brand.color, in: Circle())
            Text("Savour something")
                .typeToken(.headline)
                .foregroundStyle(Palette.textPrimary.color)
            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { newOrigin in
            origin = newOrigin
            // `-showHand` holds the hand out (Cafés lifted) for screenshots: a real press can't be
            // paused mid-gesture in a UI test.
            if Self.showsHandForScreenshots, !hand.isShown {
                hand = HandState(isShown: true, selection: 0, origin: newOrigin)
            }
        }
        .gesture(press)
        .detentHaptic(trigger: hand.selection)
        .haptic(.pick, trigger: draws)
        .popoverTip(tip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Savour something")
        .accessibilityHint("Opens quick log. Actions draw a keepsake directly.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, tap)
        .accessibilityActions {
            ForEach(hand8) { collection in
                Button(collection.savourPhrase) { draw(collection) }
            }
        }
        .accessibilityIdentifier("quickLogButton")
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !isPressing {
                    isPressing = true
                    startHoldTimer()
                }
                if !hand.isShown, value.translation.height < -Self.slideToShow {
                    showHand()
                }
                if hand.isShown {
                    hand.selection = HandLayout(count: hand8.count).selection(for: value.translation)
                }
            }
            .onEnded { value in
                holdTimer?.cancel()
                isPressing = false
                let wasShown = hand.isShown
                let pick = HandLayout(count: hand8.count).selection(for: value.translation)
                hand.isShown = false
                hand.selection = nil
                if let pick {
                    draw(hand8[pick])
                } else if !wasShown, hypot(value.translation.width, value.translation.height) < Self.tapSlop {
                    tap()
                }
                // Otherwise the slide ended in the dead zone or below the pill: cancelled.
            }
    }

    private func startHoldTimer() {
        holdTimer = Task { @MainActor in
            try? await Task.sleep(for: Self.holdDelay)
            guard !Task.isCancelled, isPressing else { return }
            showHand()
        }
    }

    private func showHand() {
        guard !hand8.isEmpty else { return }
        hand.origin = origin
        hand.isShown = true
    }

    private static let showsHandForScreenshots = ProcessInfo.processInfo.arguments.contains("-showHand")

    private func tap() {
        Task { await HoldToDrawTip.tapOpened.donate() }
        onTap()
    }

    private func draw(_ collection: ExperienceCollection) {
        draws += 1
        tip.invalidate(reason: .actionPerformed)
        onDraw(collection)
    }
}
