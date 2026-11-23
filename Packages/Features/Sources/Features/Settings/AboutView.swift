import DesignSystem
import SwiftUI

/// The Colophon: the ā mark on the aubergine field, what the name means, how the app is set,
/// the privacy seal and the version.
struct AboutView: View {
    var version = AppVersion.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                AMark()
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xl)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Asvada")
                        .typeToken(.display)
                        .foregroundStyle(Palette.onAubergine.color)
                        .accessibilityAddTraits(.isHeader)
                    Text("āsvāda · आस्वाद")
                        .typeToken(.title)
                        .foregroundStyle(Palette.saffron.color)
                        .accessibilityLabel("Aasvaada, written in Devanagari as आस्वाद")
                }
                Text(
                    """
                    In Sanskrit, āsvāda means savouring, relishing: the taste of something \
                    and the pleasure of lingering over it.
                    """,
                )
                .typeToken(.voice)
                .foregroundStyle(Palette.onAubergine.color)
                PrivacySeal()
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Colophon")
                        .typeToken(.ticketLabel)
                        .foregroundStyle(Palette.saffron.color)
                    Text("Set in New York and SF Pro. Keepsakes sealed with the ā.")
                        .typeToken(.callout)
                        .foregroundStyle(Palette.onAubergine.color.opacity(0.85))
                    Text("Maps from Natural Earth (public domain). Airline data © OpenFlights contributors, ODbL.")
                        .typeToken(.caption)
                        .foregroundStyle(Palette.onAubergine.color.opacity(0.7))
                        .accessibilityIdentifier("dataCredits")
                    Text(version.displayString)
                        .typeToken(.code)
                        .foregroundStyle(Palette.onAubergine.color.opacity(0.85))
                        .accessibilityIdentifier("appVersion")
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [Palette.aubergineTop.color, Palette.aubergineBottom.color],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea(),
        )
        .navigationTitle("About")
        .darkNavigationBar()
    }
}

#if os(iOS)
    private extension View {
        /// Cream nav-bar text on the dark aubergine field. `toolbarColorScheme` only takes effect
        /// when the bar has a visible background, so paint the bar the top of the gradient.
        func darkNavigationBar() -> some View {
            navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Palette.aubergineTop.color, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

#else
    private extension View {
        /// macOS (package tests only) has no navigation bar to recolour.
        func darkNavigationBar() -> some View {
            self
        }
    }
#endif

/// The serif "a" with its saffron macron: the app's mark.
struct AMark: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack(alignment: .top) {
            Text("a")
                .font(.system(size: size, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.onAubergine.color)
                .padding(.top, size * 0.16)
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.saffron.color)
                .frame(width: size * 0.44, height: size * 0.09)
                .padding(.top, size * 0.1)
        }
        .accessibilityHidden(true)
    }
}

/// What leaves the phone, in one sentence.
private struct PrivacySeal: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(Palette.saffron.color)
                .accessibilityHidden(true)
            Text(
                """
                Nothing leaves this phone except film lookups (TMDB), map tiles and, if you turn it \
                on, your own iCloud.
                """,
            )
            .typeToken(.callout)
            .foregroundStyle(Palette.onAubergine.color)
        }
        .padding(Spacing.large)
        .background(Palette.onAubergine.color.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Palette.saffron.color.opacity(0.4)))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AboutView(version: AppVersion(infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7"]))
    }
}
