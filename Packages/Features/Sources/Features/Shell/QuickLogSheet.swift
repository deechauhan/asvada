import DesignSystem
import SwiftUI

/// Placeholder quick-log sheet: pick what you're logging. The real flow arrives with E6.
struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(CollectionAccent.allCases) { accent in
                Label {
                    Text(accent.displayName).foregroundStyle(Palette.textPrimary.color)
                } icon: {
                    Image(systemName: accent.symbol).foregroundStyle(accent.token.color)
                }
                .accessibilityElement(children: .combine)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("What did you savour?")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private extension View {
    /// Inline titles on iOS; no-op on macOS (where this package's tests also build).
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
