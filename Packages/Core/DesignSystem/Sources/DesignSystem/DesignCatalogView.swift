import SwiftUI

/// Shows every design token. Open it from a preview, or launch the app with `-designCatalog`.
public struct DesignCatalogView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Colours") {
                    ForEach(Palette.all) { ColorRow(token: $0) }
                }
                Section("Collection accents") {
                    ForEach(CollectionAccent.allCases) { accent in
                        Label {
                            Text(accent.displayName).foregroundStyle(Palette.textPrimary.color)
                        } icon: {
                            Image(systemName: accent.symbol).foregroundStyle(accent.token.color)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section("Type") {
                    ForEach(TypeToken.allCases) { token in
                        Text("\(token.rawValue.capitalized) · Savour what you've lived")
                            .typeToken(token)
                            .foregroundStyle(Palette.textPrimary.color)
                    }
                }
                Section("Spacing") {
                    ForEach(Spacing.scale, id: \.name) { step in
                        HStack(spacing: Spacing.medium) {
                            RoundedRectangle(cornerRadius: Radius.small / 2)
                                .fill(Palette.brand.color)
                                .frame(width: step.value * 4, height: Spacing.small)
                                .accessibilityHidden(true)
                            Text("\(step.name) · \(Int(step.value)) pt")
                                .typeToken(.callout)
                                .foregroundStyle(Palette.textSecondary.color)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("Design catalogue")
        }
    }
}

private struct ColorRow: View {
    let token: ColorToken

    var body: some View {
        HStack(spacing: Spacing.medium) {
            RoundedRectangle(cornerRadius: Radius.small)
                .fill(token.color)
                .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Palette.separator.color))
                .frame(width: 44, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(token.name).typeToken(.body).foregroundStyle(Palette.textPrimary.color)
                Text("\(token.light.hexString) / \(token.dark.hexString)")
                    .typeToken(.caption)
                    .monospaced()
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    DesignCatalogView().preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignCatalogView().preferredColorScheme(.dark)
}
