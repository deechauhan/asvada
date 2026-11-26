import DesignSystem
import Model
import SwiftUI

/// One drawer as the turning cabinet shows it: a deep drawer front with a brass card holder for
/// the label, a cup pull, and the drawer's stat, with its best three keepsakes standing in the
/// tray behind. When the drawer eases ajar they rise out of it; pulling it rises them further.
struct DrumDrawer: View {
    let collection: ExperienceCollection
    /// Whether the drawer is ajar (the roll has settled on it).
    var isAjar = false
    /// How far the drawer is being pulled toward you, in points.
    var pull: Double = 0
    /// Pulls out what this drawer holds from this day in earlier years; the saffron tab shows
    /// when there is something (#69).
    var onAnniversary: (() -> Void)?

    /// The size every drawer is drawn at on the drum.
    static let size = CGSize(width: 248, height: 236)
    /// The height of the drawer front; the tray of keepsakes sits above it.
    static let frontHeight: CGFloat = 132

    private var accent: CollectionAccent {
        collection.accent
    }

    /// Keepsakes peek over the front when shut, rise when ajar, and further as it's pulled.
    private var rise: CGFloat {
        guard isAjar else { return 0 }
        return 36 + CGFloat(max(pull, 0)) * 0.35
    }

    var body: some View {
        let summary = collection.drawerSummary
        ZStack(alignment: .bottom) {
            DrawerFan(collection: collection, items: collection.drawerItems(), rise: rise)
                .frame(width: Self.size.width - 24, height: 92)
                .padding(.bottom, Self.frontHeight - 46)
            front(summary: summary)
                .overlay(alignment: .topTrailing) {
                    if let onAnniversary, !collection.anniversaries().isEmpty {
                        AnniversaryTab(action: onAnniversary)
                            .offset(x: -Spacing.medium, y: -20)
                    }
                }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .bottom)
        // The whole drawer (tray and front) answers taps, not just its painted parts.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collection.name) drawer")
        .accessibilityValue(summary.spoken)
        .accessibilityIdentifier("drawer-\(collection.kind.rawValue)-\(collection.name)")
    }

    private func front(summary: DrawerSummary) -> some View {
        VStack(spacing: Spacing.small) {
            CardHolder(name: collection.name, icon: collection.icon, ink: accent.token.color)
            CupPull()
            Spacer(minLength: 0)
            DrumStat(summary: summary)
        }
        .padding(.top, Spacing.medium)
        .padding(.bottom, Spacing.small)
        .padding(.horizontal, Spacing.medium)
        .frame(width: Self.size.width, height: Self.frontHeight)
        .background(
            LinearGradient(
                colors: [Palette.surface.color, Palette.background.color],
                startPoint: .top,
                endPoint: .bottom,
            ),
            in: RoundedRectangle(cornerRadius: Radius.medium),
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder(Palette.separator.color, lineWidth: 1),
        )
        .overlay(alignment: .bottom) {
            // The collection's ink along the lip, so drawers are told apart at a glance.
            Rectangle()
                .fill(accent.token.color.opacity(0.75))
                .frame(height: 3)
                .padding(.horizontal, Spacing.large)
                .accessibilityHidden(true)
        }
        .shadow(color: Palette.textPrimary.color.opacity(0.18), radius: 10, y: 6)
    }
}

/// The blank drawer at the end of the ring: a dashed front that starts a new collection.
struct BlankDrawer: View {
    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
            Text("New collection")
                .typeToken(.callout)
            Text("a blank tag for anything")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
        }
        .foregroundStyle(Palette.brand.color)
        .frame(width: DrumDrawer.size.width, height: DrumDrawer.frontHeight)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder(Palette.brand.color.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])),
        )
        .frame(width: DrumDrawer.size.width, height: DrumDrawer.size.height, alignment: .bottom)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New collection")
        .accessibilityIdentifier("drawer-new")
    }
}

/// The brass card holder on a drawer front, with the collection's label slipped in.
private struct CardHolder: View {
    let name: String
    let icon: String
    let ink: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
            Text(name)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xs)
        .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Palette.saffron.color.opacity(0.7), lineWidth: 1.5)
                .padding(-2),
        )
        .accessibilityHidden(true)
    }
}

/// The cup pull: a shallow handle that says "pull me toward you".
private struct CupPull: View {
    var body: some View {
        Capsule()
            .fill(Palette.textSecondary.color.opacity(0.25))
            .frame(width: 54, height: 10)
            .overlay(
                Capsule()
                    .strokeBorder(Palette.textSecondary.color.opacity(0.45), lineWidth: 1),
            )
            .accessibilityHidden(true)
    }
}

/// The drawer's stat in serif numerals, or the ghost line when it's empty (never a bare "0").
private struct DrumStat: View {
    let summary: DrawerSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            if let numeral = summary.numeral {
                Text(numeral)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.brand.color)
            }
            Text(summary.caption)
                .font(summary.numeral == nil ? .system(.footnote, design: .serif).italic() : .caption)
                .foregroundStyle(Palette.textSecondary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
    }
}
