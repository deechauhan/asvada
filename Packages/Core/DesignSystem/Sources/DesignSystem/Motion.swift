import SwiftUI

/// "Paper physics": the shared motion vocabulary. Things have weight: keepsakes land and settle,
/// stamps thunk, cards flip. Nothing slides in linearly, and there's one hero animation per
/// screen.
///
/// Reduce Motion: no tilt and no fly-to, crossfade only (haptics are kept). Use the
/// `reduceMotion`-aware helpers below rather than checking the setting at each call site.
public enum Motion {
    /// A keepsake landing: a spring with a touch of overshoot.
    public static let settle = Animation.spring(response: 0.45, dampingFraction: 0.72)
    /// A card turning over.
    public static let flip = Animation.snappy(duration: 0.6)
    /// The delay between items arriving one after another.
    public static let stagger = 0.04
    /// How long the ā is held to seal.
    public static let sealHold = 0.6
    /// What every animation becomes under Reduce Motion: a short crossfade.
    public static let crossfade = Animation.easeInOut(duration: 0.2)

    /// The thunk of a stamp or seal landing, as (scale, seconds) steps after it appears.
    public static let thunk: [(scale: Double, duration: Double)] = [(1.18, 0.09), (0.97, 0.07), (1, 0.12)]

    /// The scale a thunking view starts from before it lands.
    public static let thunkStart = 1.6

    /// `animation`, or the crossfade under Reduce Motion.
    public static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : animation
    }

    /// The delay for the `index`th item in a staggered arrival (none under Reduce Motion).
    public static func staggerDelay(_ index: Int, reduceMotion: Bool = false) -> Double {
        reduceMotion ? 0 : Double(max(index, 0)) * stagger
    }

    /// How a keepsake arrives: it drops in, slightly large, and settles. A plain fade under
    /// Reduce Motion.
    public static func landing(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 1.08).combined(with: .offset(y: -24)).combined(with: .opacity)
    }

    /// A deterministic lean, or none under Reduce Motion.
    public static func tilt(_ degrees: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : degrees
    }
}

public extension View {
    /// Leans the view by `degrees` (kept upright under Reduce Motion).
    func paperTilt(_ degrees: Double, anchor: UnitPoint = .center) -> some View {
        modifier(PaperTilt(degrees: degrees, anchor: anchor))
    }

    /// Lands the view with the thunk (1.6 → 1.18 → 0.97 → 1) each time `trigger` changes. Flat
    /// under Reduce Motion.
    func thunk(trigger: some Equatable) -> some View {
        modifier(Thunk(trigger: trigger))
    }
}

private struct PaperTilt: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let degrees: Double
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(Motion.tilt(degrees, reduceMotion: reduceMotion)), anchor: anchor)
    }
}

private struct Thunk<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Trigger

    /// The scale for thunk step `index` (flat under Reduce Motion).
    private func landing(_ index: Int) -> Double {
        reduceMotion ? 1.0 : Motion.thunk[index].scale
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: reduceMotion ? 1.0 : Motion.thunkStart, trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(landing(0), duration: Motion.thunk[0].duration)
                CubicKeyframe(landing(1), duration: Motion.thunk[1].duration)
                SpringKeyframe(landing(2), duration: Motion.thunk[2].duration)
            }
        }
    }
}
