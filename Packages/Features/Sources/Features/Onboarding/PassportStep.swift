import DesignSystem
import Geo
import SwiftUI

/// "Your passport so far." The stamps on a spread, with the first chance to share.
struct PassportStep: View {
    let stamped: Set<String>
    let onContinue: () -> Void
    @State private var image: Image?

    private var stamps: [StampEntry] {
        stamped.sorted().compactMap { code in
            CountryCatalog.shared.country(code: code).map { StampEntry(country: $0.name, code: $0.code) }
        }
    }

    var body: some View {
        OnboardingPage(title: "Your passport so far", onContinue: onContinue) {
            if stamps.isEmpty {
                Text("No stamps yet. You can add countries any time from Collections.")
                    .typeToken(.voice)
                    .foregroundStyle(Palette.textSecondary.color)
                Spacer()
            } else {
                PassportSpreadCard(stamps: stamps)
                    .scaleEffect(0.9)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("passportSpread")
                if let image {
                    ShareLink(item: image, preview: SharePreview("My passport · Artifacts", image: image)) {
                        Label("Share my passport", systemImage: "square.and.arrow.up")
                            .typeToken(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("sharePassport")
                }
                Spacer(minLength: 0)
            }
        }
        .task {
            guard !stamps.isEmpty else { return }
            image = ShareCard.render(PassportSpreadCard(stamps: stamps))
        }
    }
}
