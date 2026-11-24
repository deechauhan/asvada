import DesignSystem
import Model
import SwiftUI
import TipKit
#if os(iOS)
    import UIKit
#endif

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
        .pressTracking(changed: pressChanged, ended: pressEnded, cancelled: pressCancelled)
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

    // MARK: - The press

    /// The finger moved (or touched down): `translation` is from where it pressed.
    private func pressChanged(_ translation: CGSize) {
        if !isPressing {
            isPressing = true
            startHoldTimer()
        }
        if !hand.isShown, translation.height < -Self.slideToShow {
            showHand()
        }
        if hand.isShown {
            hand.selection = HandLayout(count: hand8.count).selection(for: translation)
        }
    }

    /// The finger lifted: draw the blank it's on (even a flick before the hand appeared), tap if
    /// it barely moved, otherwise it was a cancelled slide.
    private func pressEnded(_ translation: CGSize) {
        holdTimer?.cancel()
        isPressing = false
        let wasShown = hand.isShown
        let pick = HandLayout(count: hand8.count).selection(for: translation)
        hand.isShown = false
        hand.selection = nil
        if let pick {
            draw(hand8[pick])
        } else if !wasShown, hypot(translation.width, translation.height) < Self.tapSlop {
            tap()
        }
    }

    /// The system took the touch away: draw whichever blank was lifted, if any.
    private func pressCancelled() {
        holdTimer?.cancel()
        isPressing = false
        let lifted = hand.selection
        hand.isShown = false
        hand.selection = nil
        if let lifted, hand8.indices.contains(lifted) {
            draw(hand8[lifted])
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

private extension View {
    /// Follows a press on the pill from touch-down to lift, even once the finger leaves it.
    func pressTracking(
        changed: @escaping (CGSize) -> Void,
        ended: @escaping (CGSize) -> Void,
        cancelled: @escaping () -> Void,
    ) -> some View {
        #if os(iOS)
            // A UIKit recogniser (ADR-0004's fallback): it keeps tracking outside the tab-bar
            // accessory and recognises alongside the system's own gestures there, where a SwiftUI
            // drag was cancelled without ever ending.
            gesture(PressRecognizer(changed: changed, ended: ended, cancelled: cancelled))
        #else
            gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { changed($0.translation) }
                    .onEnded { ended($0.translation) },
            )
        #endif
    }
}

#if os(iOS)
    /// A long-press recogniser with no delay and unlimited movement: a touch tracker reporting
    /// the finger's travel from where it pressed, in window coordinates.
    private struct PressRecognizer: UIGestureRecognizerRepresentable {
        let changed: (CGSize) -> Void
        let ended: (CGSize) -> Void
        let cancelled: () -> Void

        @MainActor
        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            var start: CGPoint = .zero

            func gestureRecognizer(
                _: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer,
            ) -> Bool {
                true
            }
        }

        func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
            Coordinator()
        }

        func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
            let recognizer = UILongPressGestureRecognizer()
            recognizer.minimumPressDuration = 0
            recognizer.allowableMovement = .greatestFiniteMagnitude
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = context.coordinator
            return recognizer
        }

        func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
            let point = recognizer.location(in: nil)
            let start = context.coordinator.start
            let translation = CGSize(width: point.x - start.x, height: point.y - start.y)
            switch recognizer.state {
            case .began:
                context.coordinator.start = point
                changed(.zero)
            case .changed:
                changed(translation)
            case .ended:
                ended(translation)
            case .cancelled, .failed:
                cancelled()
            default:
                break
            }
        }
    }
#endif
