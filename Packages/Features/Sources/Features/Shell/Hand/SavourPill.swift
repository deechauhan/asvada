import DesignSystem
import Model
import SwiftUI
import TipKit
#if os(iOS)
    import UIKit
#endif

/// Where the pill is on screen, shared without re-rendering the tab view: only the press catcher
/// and the hand read it. (Writing it into the shell's own state re-rendered the tab view, which
/// laid the pill out again, endlessly.)
@MainActor
@Observable
final class PillFrame {
    var frame: CGRect = .zero
    /// Which pill set `frame`. Switching tabs makes a new pill before the old one disappears, so
    /// only the pill that owns the frame may clear it.
    var owner: UUID?

    var centre: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// What the shell needs to draw the hand: whether it's out and which blank the thumb is on.
struct HandState: Equatable {
    var isShown = false
    var selection: Int?
}

/// The savour pill's face, in the tab-bar accessory (INTERACTION.md §5): the ā, "Savour
/// something" and a chevron hinting that it slides up. Its touches are handled by
/// `PillPressCatcher`, which sits over it above the tab bar; VoiceOver uses the pill itself: a
/// button that opens quick-log, with one action per blank.
struct SavourPill: View {
    /// The visible collections, in cabinet order (the hand holds the first eight).
    let collections: [ExperienceCollection]
    let frame: PillFrame
    let onTap: () -> Void
    let onDraw: (ExperienceCollection) -> Void

    private let tip = HoldToDrawTip()
    @State private var identity = UUID()
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The ā badge grows with the reader's text size.
    @ScaledMetric(relativeTo: .headline) private var badge: CGFloat = 26

    var body: some View {
        HStack(spacing: Spacing.small) {
            if typeSize.isAccessibilitySize {
                // The accessory is only so tall: at accessibility sizes the plum ā stands alone,
                // free to grow, rather than squeezed into a circle.
                Text("ā")
                    .font(.system(.headline, design: .serif, weight: .heavy))
                    .foregroundStyle(Palette.brand.color)
            } else {
                Text("ā")
                    .font(.system(.subheadline, design: .serif, weight: .heavy))
                    .foregroundStyle(Palette.onBrand.color)
                    .frame(width: badge, height: badge)
                    .background(Palette.brand.color, in: Circle())
            }
            // The accessory can't grow to hold a wrapped label at accessibility sizes, so there the
            // ā stands for it; the label stays for VoiceOver and Voice Control.
            if !typeSize.isAccessibilitySize {
                Text("Savour something")
                    .typeToken(.headline)
                    .foregroundStyle(Palette.textPrimary.color)
            }
            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { newFrame in
            // An @Observable setter notifies even for an equal value.
            if frame.frame != newFrame || frame.owner != identity {
                frame.frame = newFrame
                frame.owner = identity
            }
        }
        .onDisappear {
            guard frame.owner == identity else { return }
            frame.frame = .zero
            frame.owner = nil
        }
        // Normally the catcher above the tab bar takes the touch; this covers any moment it isn't
        // there (between tabs, say).
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .popoverTip(tip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Savour something")
        .accessibilityHint("Opens quick log. Actions draw a keepsake directly.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
        .accessibilityActions {
            ForEach(collections.prefix(HandLayout.maximumCount)) { collection in
                Button(collection.savourPhrase) { onDraw(collection) }
            }
        }
        .accessibilityIdentifier("quickLogButton")
    }
}

/// An invisible patch over the pill, in the shell's overlay above the tab bar, that handles its
/// touches. (Inside the tab-bar accessory the system's own tab-bar drags took the touch as soon as
/// the finger slid, so a slide never ended on the pill.)
///
/// A tap opens quick-log. Holding for 170 ms, or sliding up more than 8 pt, fans the hand of
/// blanks out over the thumb; sliding onto a blank lifts it and letting go draws it. A quick flick
/// draws the same blank before the hand has even appeared, because the blanks never move. Sliding
/// below the pill cancels.
struct PillPressCatcher: View {
    let collections: [ExperienceCollection]
    let frame: PillFrame
    @Binding var hand: HandState
    let onTap: () -> Void
    let onDraw: (ExperienceCollection) -> Void

    /// How long a press must last before the hand fans out.
    static let holdDelay = Duration.milliseconds(170)
    /// How far up a slide must go to bring the hand out early.
    static let slideToShow: CGFloat = 8
    /// The most a press can move and still count as a tap.
    static let tapSlop: CGFloat = 10
    /// A still press shorter than this is a tap even if the hand came out: on a busy main thread
    /// the hold timer can fire before the lift is handled, and a tap must never be lost.
    static let tapDuration: TimeInterval = 0.35

    /// Whether a press that drew nothing was a tap: it barely moved, and either the hand never
    /// came out or the press was quick anyway.
    static func isTap(distance: CGFloat, duration: TimeInterval, handWasShown: Bool) -> Bool {
        guard distance < tapSlop else { return false }
        return !handWasShown || duration < tapDuration
    }

    @State private var isPressing = false
    @State private var pressStarted = Date.distantPast
    @State private var lastTranslation = CGSize.zero
    @State private var holdTimer: Task<Void, Never>?
    @State private var draws = 0

    private var hand8: [ExperienceCollection] {
        Array(collections.prefix(HandLayout.maximumCount))
    }

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            Color.clear
                .contentShape(Rectangle())
                .frame(width: frame.frame.width, height: frame.frame.height)
                .position(x: frame.centre.x - origin.x, y: frame.centre.y - origin.y)
                .pressTracking(changed: pressChanged, ended: pressEnded, cancelled: pressCancelled)
        }
        .ignoresSafeArea()
        .detentHaptic(trigger: hand.selection)
        .haptic(.pick, trigger: draws)
        .onChange(of: frame.frame) { _, newFrame in
            // `-showHand` holds the hand out (Cafés lifted) for screenshots: a real press can't be
            // paused mid-gesture in a UI test.
            if Self.showsHandForScreenshots, !hand.isShown, newFrame != .zero {
                hand = HandState(isShown: true, selection: 0)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - The press

    /// The finger moved (or touched down): `translation` is from where it pressed.
    private func pressChanged(_ translation: CGSize) {
        if !isPressing {
            isPressing = true
            pressStarted = .now
            startHoldTimer()
        }
        lastTranslation = translation
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
        } else if Self.isTap(
            distance: hypot(translation.width, translation.height),
            duration: Date.now.timeIntervalSince(pressStarted),
            handWasShown: wasShown,
        ) {
            tap()
        }
    }

    /// The system took the touch away: draw whichever blank was lifted, if any, or open
    /// quick-log if it was really a tap (a quick press that never moved).
    private func pressCancelled() {
        holdTimer?.cancel()
        isPressing = false
        let lifted = hand.selection
        hand.isShown = false
        hand.selection = nil
        if let lifted, hand8.indices.contains(lifted) {
            draw(hand8[lifted])
        } else if Self.isTap(
            distance: hypot(lastTranslation.width, lastTranslation.height),
            duration: Date.now.timeIntervalSince(pressStarted),
            // A cancelled press only counts if it was quick, whether or not the hand showed.
            handWasShown: true,
        ) {
            tap()
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
        hand.isShown = true
    }

    private static let showsHandForScreenshots = ProcessInfo.processInfo.arguments.contains("-showHand")

    private func tap() {
        Task { await HoldToDrawTip.tapOpened.donate() }
        onTap()
    }

    private func draw(_ collection: ExperienceCollection) {
        draws += 1
        HoldToDrawTip().invalidate(reason: .actionPerformed)
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
