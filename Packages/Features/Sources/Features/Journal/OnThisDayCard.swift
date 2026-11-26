import DesignSystem
import Model
import SwiftUI

/// The Journal's "on this day" card (#69): a keepsake lying face down. Tap it and it turns over
/// to show "A year ago, you savoured…" and what it was; tap a thing for its page. Under Reduce
/// Motion it crossfades instead of turning.
struct OnThisDayCard: View {
    let anniversaries: [Anniversary]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFaceUp = false

    var body: some View {
        ZStack {
            back
                .opacity(isFaceUp ? 0 : 1)
            front
                .opacity(isFaceUp ? 1 : 0)
                // The face is drawn turned so it reads the right way round once the card has flipped.
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFaceUp && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .paperTilt(-1)
        .accessibilityIdentifier("onThisDayCard")
    }

    /// Face down: the paper back with a saffron macron and a question.
    private var back: some View {
        Button(action: turnOver) {
            VStack(spacing: Spacing.small) {
                Text("On this day")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(Palette.textSecondary.color)
                Text("?")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.brand.color)
                MacronBar(progress: 1, height: 3)
                    .frame(width: 40)
                Text("Tap to turn it over")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.keepsake))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.keepsake)
                    .strokeBorder(Palette.separator.color, lineWidth: 1),
            )
            .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("On this day, a keepsake face down")
        .accessibilityHint("Turns it over")
        .accessibilityIdentifier("onThisDayBack")
        .allowsHitTesting(!isFaceUp)
        .accessibilityHidden(isFaceUp)
    }

    /// Face up: the headline in serif, then each thing and how long ago.
    private var front: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(OnThisDay.headline(anniversaries) ?? "")
                .typeToken(.voice)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityIdentifier("onThisDayHeadline")
            ForEach(anniversaries) { anniversary in
                NavigationLink {
                    ItemDetailScreen(item: anniversary.item)
                } label: {
                    HStack {
                        if let collection = anniversary.item.collection {
                            Image(systemName: collection.icon)
                                .foregroundStyle(collection.accent.token.color)
                                .accessibilityHidden(true)
                        }
                        Text(anniversary.item.name)
                            .typeToken(.body)
                            .foregroundStyle(Palette.textPrimary.color)
                        Spacer(minLength: 0)
                        Text(OnThisDay.ago(anniversary.yearsAgo))
                            .font(.system(.footnote, design: .serif).italic())
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.keepsake))
        .overlay(alignment: .top) {
            MacronBar(progress: 1, height: 3)
                .padding(.horizontal, Spacing.xl)
        }
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 8, y: 4)
        .allowsHitTesting(isFaceUp)
        .accessibilityHidden(!isFaceUp)
    }

    private func turnOver() {
        withAnimation(Motion.animation(Motion.flip, reduceMotion: reduceMotion)) {
            isFaceUp = true
        }
    }
}

/// What a drawer's saffron tab pulls out: its "on this day" card, face down, in a sheet.
struct OnThisDaySheet: View {
    let collection: ExperienceCollection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                OnThisDayCard(anniversaries: collection.anniversaries())
                    .padding(Spacing.large)
            }
            .background(Palette.background.color)
            .navigationTitle(collection.name)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The saffron-macron tab an anniversary keepsake sticks up on, from its drawer in the cabinet
/// and the chest. Tapping it pulls the keepsake out face down.
struct AnniversaryTab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("On this day")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary.color)
                MacronBar(progress: 1, height: 2)
                    .frame(width: 26)
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xxs)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                    .fill(Palette.keepsakePaper.color),
            )
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                    .strokeBorder(Palette.saffron.color.opacity(0.8), lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("On this day")
        .accessibilityHint("Pulls out what you savoured on this day")
        .accessibilityIdentifier("anniversaryTab")
    }
}
