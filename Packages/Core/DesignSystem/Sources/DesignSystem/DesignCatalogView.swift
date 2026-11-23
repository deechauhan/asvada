import SwiftUI

/// Shows every design token. Open it from a preview, or launch the app with `-designCatalog`.
public struct DesignCatalogView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HeroFieldSample()
                        .listRowInsets(EdgeInsets())
                }
                Section("Keepsakes") {
                    NavigationLink("Keepsake gallery") {
                        KeepsakeGallery()
                    }
                }
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
                        Text(token == .code ? "BA 0117 · LHR → HND" : "\(token.rawValue) · Savour what you've lived")
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

/// The aubergine hero field with the serif ā and its saffron macron.
private struct HeroFieldSample: View {
    var body: some View {
        HStack(spacing: Spacing.large) {
            ZStack(alignment: .top) {
                Text("a")
                    .font(.system(size: 64, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.onAubergine.color)
                    .padding(.top, Spacing.small)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.saffron.color)
                    .frame(width: 30, height: 6)
                    .offset(y: 10)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Savour what you've lived")
                    .typeToken(.voice)
                    .foregroundStyle(Palette.onAubergine.color)
                Text("Aubergine field · plum ink · saffron spark")
                    .typeToken(.caption)
                    .foregroundStyle(Palette.saffron.color)
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            ),
        )
        .accessibilityElement(children: .combine)
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
