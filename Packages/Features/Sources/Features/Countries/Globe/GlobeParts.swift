import DesignSystem
import Geo
import SwiftUI

/// A glass button on the globe: Unroll, Roll up, or the plum Stamp.
struct GlobeButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .typeToken(prominent ? .headline : .callout)
                .foregroundStyle(prominent ? Palette.onBrand.color : Palette.textPrimary.color)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(Palette.brand.color).interactive() : .regular.interactive(), in: Capsule())
        .padding(Spacing.xs)
        .accessibilityIdentifier(identifier)
    }
}

/// Picks between small neighbours near the ring ("Luxembourg · Belgium · Netherlands"); the one
/// aimed at is inked.
struct GlobeChips: View {
    let codes: [String]
    let aimed: String?
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(codes, id: \.self) { code in
                    chip(code)
                }
            }
            .padding(Spacing.xxs)
        }
        .scrollClipDisabled()
    }

    private func chip(_ code: String) -> some View {
        let isAimed = code == aimed
        return Button {
            onPick(code)
        } label: {
            Text(CountryCatalog.shared.country(code: code)?.name ?? code)
                .typeToken(.caption)
                .foregroundStyle(isAimed ? Palette.onBrand.color : Palette.textPrimary.color)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xxs)
                .background(isAimed ? Palette.brand.color : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .accessibilityAddTraits(isAimed ? .isSelected : [])
        .accessibilityHint("Turns the globe to it")
        .accessibilityIdentifier("globeChip-\(code)")
    }
}
