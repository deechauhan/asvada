import DesignSystem
import Model
import Storage
import SwiftUI

/// The app's root screen. A placeholder until the app shell story lands.
public struct RootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Asvada")
                .typeToken(.display)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Text("Savour what you've lived")
                .typeToken(.headline)
                .foregroundStyle(Palette.textSecondary.color)
            Text(FeaturesModule.linkedModules.joined(separator: " · "))
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityLabel("Linked modules: \(FeaturesModule.linkedModules.joined(separator: ", "))")
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
    }
}

#Preview {
    RootView()
}
