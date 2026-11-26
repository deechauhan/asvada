import DesignSystem
import SwiftUI

/// What leaves the phone, exactly (#60): each online source and what it is sent, then what never
/// does. Written from `DataSource.all`, the same list About credits, so the two stay in step.
struct PrivacyView: View {
    private var online: [DataSource] {
        DataSource.all.filter(\.isOnline)
    }

    private var bundled: [DataSource] {
        DataSource.all.filter { !$0.isOnline }
    }

    var body: some View {
        List {
            Section {
                Text(
                    """
                    Your keepsakes, photos, notes and ratings live on this phone, in the app's own \
                    storage. There's no account, no tracking and no server of ours.
                    """,
                )
                .typeToken(.callout)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityIdentifier("privacySummary")
            }
            Section("What leaves this phone") {
                ForEach(online) { source in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(source.name)
                            .typeToken(.headline)
                        Text(source.sends)
                            .typeToken(.callout)
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("privacy-\(source.id)")
                }
            }
            Section("Built in, nothing sent") {
                ForEach(bundled) { source in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(source.name)
                            .typeToken(.headline)
                        Text(source.provides)
                            .typeToken(.callout)
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("privacy-\(source.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("Privacy")
    }
}
