import SwiftUI
import TipKit
#if os(iOS) && canImport(CoreHaptics)
    import CoreHaptics
#endif

/// The last step of every log: hold the ā for 0.6 s. Plum ink rises inside it while the
/// haptic builds, then `action` runs (the caller stamps a `WaxSeal` on the keepsake).
///
/// - Releasing early cancels.
/// - VoiceOver: a "Savour" action seals immediately.
/// - After the first successful hold a plain tap also seals (the tip has taught the gesture).
public struct SealButton: View {
    public static let holdDuration = Motion.sealHold

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("seal.hasLearnedHold") private var hasLearnedHold = false
    @State private var progress = 0.0
    @State private var sealed = 0
    @State private var haptics = SealHaptics()
    private let tip = SavourTip()
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Palette.surfaceRaised.color)
            Circle()
                .fill(Palette.brand.color)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: 88 * progress)
                }
            AMarkGlyph(ink: progress > 0.55 ? Palette.onBrand.color : Palette.brand.color)
        }
        .frame(width: 88, height: 88)
        .glassEffect(.regular.tint(Palette.brand.color.opacity(0.25)).interactive(), in: Circle())
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 40) {
            complete()
        } onPressingChanged: { pressing in
            if pressing {
                haptics.startRamp(duration: Self.holdDuration)
                withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
            } else if progress < 1 {
                haptics.cancel()
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if hasLearnedHold {
                complete()
            }
        })
        .haptic(.seal, trigger: sealed)
        .popoverTip(tip)
        .accessibilityElement()
        .accessibilityLabel("Hold to savour")
        .accessibilityHint("Seals this keepsake")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Savour") { complete() }
        .accessibilityIdentifier("sealButton")
    }

    private func complete() {
        haptics.finish()
        hasLearnedHold = true
        tip.invalidate(reason: .actionPerformed)
        sealed += 1
        action()
        withAnimation(Motion.animation(.easeOut(duration: 0.3).delay(0.25), reduceMotion: reduceMotion)) { progress = 0 }
    }
}

/// The serif "a" with its macron, drawn in one ink colour.
struct AMarkGlyph: View {
    let ink: Color

    var body: some View {
        ZStack(alignment: .top) {
            Text("a")
                .font(.system(size: 44, weight: .heavy, design: .serif))
                .padding(.top, 8)
            Capsule()
                .frame(width: 20, height: 4)
                .padding(.top, 6)
        }
        .foregroundStyle(ink)
        .accessibilityHidden(true)
    }
}

/// A small plum wax seal with the ā, stamped onto a keepsake's corner with the "thunk".
public struct WaxSeal: View {
    @State private var landed = false

    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.brand.color.opacity(0.85), Palette.brand.color],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 24,
                    ),
                )
                .shadow(color: Palette.textPrimary.color.opacity(0.3), radius: 2, y: 1)
            Text("ā")
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.onBrand.color)
        }
        .frame(width: 38, height: 38)
        .thunk(trigger: landed)
        .onAppear { landed = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sealed")
        .accessibilityIdentifier("waxSeal")
    }
}

/// Teaches the hold once; after the first seal a tap is enough.
public struct SavourTip: Tip {
    public init() {}

    public var title: Text {
        Text("Hold the ā to savour")
    }

    public var message: Text? {
        Text("Press and hold until the ink fills it. It seals this keepsake.")
    }
}

/// Core Haptics ramp (continuous 0.2 → 0.8, then a sharp transient). Falls back to the
/// `.sensoryFeedback(.success)` on the button where Core Haptics isn't available.
@MainActor
final class SealHaptics {
    #if os(iOS) && canImport(CoreHaptics)
        private var engine: CHHapticEngine?
        private var player: CHHapticPatternPlayer?

        func startRamp(duration: Double) {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                if engine == nil {
                    engine = try CHHapticEngine()
                }
                try engine?.start()
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: 0,
                    duration: duration,
                )
                let ramp = CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.2),
                        CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: 0.8),
                    ],
                    relativeTime: 0,
                )
                let pattern = try CHHapticPattern(events: [event], parameterCurves: [ramp])
                player = try engine?.makePlayer(with: pattern)
                try player?.start(atTime: CHHapticTimeImmediate)
            } catch {
                player = nil
            }
        }

        func cancel() {
            try? player?.stop(atTime: CHHapticTimeImmediate)
            player = nil
        }

        func finish() {
            cancel()
            guard let engine else { return }
            let tap = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                ],
                relativeTime: 0,
            )
            if let pattern = try? CHHapticPattern(events: [tap], parameters: []) {
                try? engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            }
        }

    #else
        func startRamp(duration _: Double) {}
        func cancel() {}
        func finish() {}
    #endif
}
