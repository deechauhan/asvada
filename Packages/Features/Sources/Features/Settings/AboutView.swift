import DesignSystem
import SwiftUI

/// Explains the name and shows the app version.
struct AboutView: View {
    var version = AppVersion.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Asvada")
                        .typeToken(.display)
                        .foregroundStyle(Palette.textPrimary.color)
                        .accessibilityAddTraits(.isHeader)
                    Text("āsvāda · आस्वाद")
                        .typeToken(.title)
                        .foregroundStyle(Palette.brand.color)
                        .accessibilityLabel("Aasvaada, written in Devanagari as आस्वाद")
                }
                Text(
                    """
                    In Sanskrit, āsvāda means savouring, relishing: the taste of something \
                    and the pleasure of lingering over it.
                    """,
                )
                .typeToken(.body)
                .foregroundStyle(Palette.textPrimary.color)
                Text(
                    """
                    Asvada is a private place to savour what you've lived: the cafés, meals, \
                    places, flights and films that made your days. Everything stays on your device.
                    """,
                )
                .typeToken(.body)
                .foregroundStyle(Palette.textSecondary.color)
                Text(version.displayString)
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
                    .accessibilityIdentifier("appVersion")
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.background.color)
        .navigationTitle("About")
    }
}

#Preview {
    NavigationStack {
        AboutView(version: AppVersion(infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7"]))
    }
}
