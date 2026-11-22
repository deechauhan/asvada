import DesignSystem
import Model
import Storage
import SwiftUI

/// The app's root screen. A placeholder until the app shell story lands.
public struct RootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Asvada")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Savour what you've lived")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(FeaturesModule.linkedModules.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Linked modules: \(FeaturesModule.linkedModules.joined(separator: ", "))")
        }
        .padding()
    }
}

#Preview {
    RootView()
}
