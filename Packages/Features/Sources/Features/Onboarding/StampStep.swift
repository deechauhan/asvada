import DesignSystem
import SwiftUI

/// "Where have you been?" The stamp pad: aim the rubber stamp at the ink map, tap through a
/// continent's strip of stamps, or type a name and press Return. The counter rolls with each one.
struct StampStep: View {
    @Binding var stamped: Set<String>
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage(title: "Where have you been?", onContinue: onContinue) {
            ScrollView {
                StampPad(stamped: $stamped)
                    .padding(.bottom, Spacing.large)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
