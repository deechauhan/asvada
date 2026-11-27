import DesignSystem
import Model
import SwiftUI

/// What the lucky dip hands you (#159): a keepsake face down (aubergine back, cream ā, saffron
/// macron). Tap it to turn it over: the keepsake, when it was savoured and its note. Then Again,
/// Open drawer (the riffle at that card) or Put back. Under Reduce Motion it crossfades.
struct LuckyDipSheet: View {
    let item: Item
    let again: () -> Void
    let openDrawer: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFaceUp = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                back
                    .opacity(isFaceUp ? 0 : 1)
                front
                    .opacity(isFaceUp ? 1 : 0)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(isFaceUp && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .frame(maxWidth: 320)
            if isFaceUp {
                actions
                    .transition(.opacity)
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("luckyDip")
    }

    /// Face down: the aubergine back with the cream ā and a saffron macron.
    private var back: some View {
        Button(action: turnOver) {
            VStack(spacing: Spacing.medium) {
                Text("ā")
                    .font(.system(size: 64, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.onAubergine.color)
                MacronBar(progress: 1, height: 4)
                    .frame(width: 48)
                Text("Tap to turn it over")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Palette.onAubergine.color.opacity(0.85))
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(
                LinearGradient(
                    colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                    startPoint: .top,
                    endPoint: .bottom,
                ),
                in: RoundedRectangle(cornerRadius: Radius.medium),
            )
            .shadow(color: Palette.textPrimary.color.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("A keepsake, face down")
        .accessibilityHint("Turns it over")
        .accessibilityIdentifier("luckyDipBack")
        .allowsHitTesting(!isFaceUp)
        .accessibilityHidden(isFaceUp)
    }

    /// Face up: the keepsake, when, and the note.
    private var front: some View {
        VStack(spacing: Spacing.medium) {
            if let collection = item.collection {
                ItemKeepsake(item: item, collection: collection)
            }
            if let latest = item.latestEntry {
                Text("savoured \(KeepsakeDate.short(latest.date))")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
                if !latest.notes.isEmpty {
                    Text("“\(latest.notes)”")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Palette.textPrimary.color)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("luckyDipFront")
        .allowsHitTesting(isFaceUp)
        .accessibilityHidden(!isFaceUp)
    }

    private var actions: some View {
        HStack(spacing: Spacing.medium) {
            Button("Again", systemImage: "dice") {
                dismiss()
                again()
            }
            .accessibilityIdentifier("luckyDipAgain")
            Button("Open drawer", systemImage: "tray.and.arrow.down") {
                dismiss()
                openDrawer()
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand.color)
            .accessibilityIdentifier("luckyDipOpen")
            Button("Put back", systemImage: "arrow.uturn.down") {
                dismiss()
            }
            .accessibilityIdentifier("luckyDipPutBack")
        }
        .buttonStyle(.bordered)
        .labelStyle(.titleAndIcon)
        .font(.callout)
    }

    private func turnOver() {
        withAnimation(Motion.animation(Motion.flip, reduceMotion: reduceMotion)) {
            isFaceUp = true
        }
    }
}
