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

#if os(iOS)
    private extension View {
        /// Inline navigation titles on iOS.
        func navigationBarTitleDisplayModeInline() -> some View {
            navigationBarTitleDisplayMode(.inline)
        }
    }

#else
    private extension View {
        /// No-op on macOS, where this package's tests also build.
        func navigationBarTitleDisplayModeInline() -> some View {
            self
        }
    }
#endif
