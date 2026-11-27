import DesignSystem
import SwiftUI

/// How films seal (#121): instead of holding the ā, drag along the stub's perforation to tear it,
/// with a light tick at each notch and the tear's rigid pattern as it parts. Holding still seals
/// it too (as the ā does), and so does VoiceOver's "Savour" action. Under Reduce Motion the stub
/// doesn't drop away as it tears.
struct TearToSeal: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far along the perforation the tear has gone, 0...1.
    @State private var progress = 0.0
    @State private var notch = 0
    @State private var fallbackTears = 0
    @State private var sealed = false
    @State private var tear = TearHaptics()

    /// The notches along the perforation, each a tick.
    static let notchCount = 8
    /// How far along the tear must get to part.
    static let partsAt = 0.9
    static let size = CGSize(width: 260, height: 72)

    var body: some View {
        ZStack(alignment: .leading) {
            stub
            Perforation(progress: progress)
                .frame(height: 2)
                .padding(.horizontal, Spacing.medium)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .contentShape(Rectangle())
        .gesture(drag)
        .simultaneousGesture(LongPressGesture(minimumDuration: Motion.sealHold).onEnded { _ in complete() })
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: notch)
        .haptic(.tear, trigger: fallbackTears)
        .accessibilityElement()
        .accessibilityLabel("Tear to savour")
        .accessibilityHint("Seals this keepsake")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { complete() }
        .accessibilityAction(named: "Savour") { complete() }
        .accessibilityIdentifier("sealButton")
    }

    /// The two halves of the stub: the lower one drops and leans away as the tear runs.
    private var stub: some View {
        VStack(spacing: 0) {
            half
            half
                .offset(y: reduceMotion ? 0 : progress * 6)
                .rotationEffect(.degrees(reduceMotion ? 0 : progress * 3), anchor: .leading)
        }
        .accessibilityHidden(true)
    }

    private var half: some View {
        Rectangle()
            .fill(Palette.keepsakePaper.color)
            .frame(height: Self.size.height / 2)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(CollectionAccent.film.token.color.opacity(0.7))
                    .frame(width: 4)
            }
            .shadow(color: Palette.textPrimary.color.opacity(0.08), radius: 2, y: 1)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !sealed else { return }
                progress = Self.progress(after: value.translation.width, width: Self.size.width, from: progress)
                notch = Self.notch(at: progress)
                if progress >= Self.partsAt {
                    complete()
                }
            }
            .onEnded { _ in
                guard !sealed else { return }
                withAnimation(Motion.animation(Motion.pull, reduceMotion: reduceMotion)) {
                    progress = 0
                }
                notch = 0
            }
    }

    private func complete() {
        guard !sealed else { return }
        sealed = true
        withAnimation(Motion.animation(.easeOut(duration: 0.2), reduceMotion: reduceMotion)) {
            progress = 1
        }
        if !tear.play() {
            fallbackTears += 1
        }
        action()
    }

    /// How far the tear has run after a drag of `translation` points along a perforation
    /// `width` long: it only runs forward (left to right), never past the end.
    static func progress(after translation: Double, width: Double, from current: Double) -> Double {
        guard width > 0 else { return current }
        return min(max(current, translation / width), 1)
    }

    /// Which notch the tear has reached (0 before the first).
    static func notch(at progress: Double) -> Int {
        Int((min(max(progress, 0), 1) * Double(notchCount)).rounded(.down))
    }
}

/// The dashed perforation, torn plum up to `progress`.
private struct Perforation: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                line(width: proxy.size.width)
                    .stroke(Palette.textSecondary.color.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                line(width: proxy.size.width * progress)
                    .stroke(Palette.brand.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private func line(width: Double) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 1))
            path.addLine(to: CGPoint(x: width, y: 1))
        }
    }
}
