import DesignSystem
import SwiftUI

/// Home. Until entries exist (quick-log, E6) it shows the empty Journal from the concept:
/// a breathing ghost keepsake and three ways to start. Settings sits behind the ā avatar.
struct JournalScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSettings = false
    @State private var breathe = false
    let onSavour: () -> Void

    private var month: String {
        Date.now.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(month)
                        .typeToken(.masthead)
                        .foregroundStyle(Palette.textPrimary.color)
                        .accessibilityAddTraits(.isHeader)
                    ghostKeepsake
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Start with something you loved:")
                            .typeToken(.voice)
                            .foregroundStyle(Palette.textSecondary.color)
                        startChip("Stamp your countries", symbol: "globe.europe.africa.fill", accent: .country)
                        startChip("Your favourite café", symbol: "cup.and.saucer.fill", accent: .cafe)
                        startChip("The last film you saw", symbol: "film.fill", accent: .film)
                    }
                }
                .padding(Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.background.color)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeadingCompat) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Text("ā")
                            .font(.system(size: 17, weight: .heavy, design: .serif))
                            .foregroundStyle(Palette.brand.color)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsScreen()
            }
        }
    }

    /// A dashed outline where the first keepsake will land, breathing gently.
    private var ghostKeepsake: some View {
        VStack(spacing: Spacing.small) {
            Text("your first keepsake")
                .typeToken(.voice)
                .foregroundStyle(Palette.textSecondary.color)
            Text("Seal something you savoured and it lands here.")
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: Radius.keepsake)
                .strokeBorder(Palette.brand.color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])),
        )
        .scaleEffect(breathe ? 1.02 : 1.0)
        .rotationEffect(.degrees(reduceMotion ? 0 : -1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityElement(children: .combine)
    }

    private func startChip(_ title: String, symbol: String, accent: CollectionAccent) -> some View {
        Button(action: onSavour) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: symbol)
                    .foregroundStyle(accent.token.color)
                    .frame(width: 32, height: 32)
                    .background(accent.token.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.keepsake))
                    .accessibilityHidden(true)
                Text(title)
                    .typeToken(.body)
                    .foregroundStyle(Palette.textPrimary.color)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary.color)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.medium)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
    }
}

extension ToolbarItemPlacement {
    /// Leading toolbar slot on iOS; automatic on macOS (package tests only).
    static var topBarLeadingCompat: ToolbarItemPlacement {
        #if os(iOS)
            .topBarLeading
        #else
            .automatic
        #endif
    }
}
