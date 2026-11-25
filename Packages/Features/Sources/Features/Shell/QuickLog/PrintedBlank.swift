import DesignSystem
import Model
import SwiftUI

/// The drawn blank with the print head's guess typed onto it, a character every 20 ms, and its
/// source line ("Again? · 1 of 3"). Swipe it left to tear the guess off, right to bring the last
/// one back. Reduce Motion crossfades instead of typing and tearing; the haptic stays.
struct PrintedBlank: View {
    let collection: ExperienceCollection
    let guess: Guess?
    let sourceLine: String?
    let canRestore: Bool
    let onTear: () -> Void
    let onRestore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = ""
    @State private var drag: CGFloat = 0

    private static let scale: CGFloat = 1.6

    var body: some View {
        VStack(spacing: Spacing.small) {
            ZStack {
                BlankKeepsake(collection: collection, isLifted: true)
                    .scaleEffect(Self.scale)
                    .frame(width: BlankKeepsake.size.width * Self.scale, height: BlankKeepsake.size.height * Self.scale)
                if guess != nil {
                    Text(shown)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary.color)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .frame(width: BlankKeepsake.size.width * Self.scale - 24)
                        .padding(.top, Spacing.large)
                }
            }
            .offset(x: reduceMotion ? 0 : drag)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag) / 40))
            .opacity(reduceMotion ? 1 : 1 - min(abs(Double(drag)) / 400, 0.5))
            .gesture(tearGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(guess.map { "Printed: \($0.title)" } ?? "Blank \(collection.name) keepsake")
            .accessibilityValue(sourceLine ?? "")
            .accessibilityAction(named: "Next guess") { onTear() }
            .accessibilityAction(named: "Previous guess") {
                if canRestore {
                    onRestore()
                }
            }
            .accessibilityIdentifier("printedGuess")
            // Always there (blank when there's no guess) so nothing below shifts as guesses come and go.
            Text(sourceLine ?? " ")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityHidden(sourceLine == nil)
                .accessibilityIdentifier("printSource")
        }
        .task(id: guess?.id) { await print(guess?.title ?? "") }
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag = $0.translation.width }
            .onEnded { value in
                switch PrintHead.swipe(translation: value.translation.width, velocity: value.velocity.width) {
                case .tear: onTear()
                case .restore:
                    if canRestore {
                        onRestore()
                    }
                case .none: break
                }
                withAnimation(Motion.animation(Motion.pull, reduceMotion: reduceMotion)) { drag = 0 }
            }
    }

    /// Types `text` onto the blank, or shows it at once under Reduce Motion.
    private func print(_ text: String) async {
        guard !reduceMotion else {
            withAnimation(Motion.crossfade) { shown = text }
            return
        }
        shown = ""
        for count in 1 ... max(text.count, 1) {
            try? await Task.sleep(for: .seconds(PrintHead.perCharacter))
            guard !Task.isCancelled else { return }
            shown = String(text.prefix(count))
        }
    }
}
