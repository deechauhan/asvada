import SwiftUI

// iOS-only modifiers behind one name each, so views build on macOS too (this package's tests
// run there) without #if at every call site.

#if os(iOS)
    extension View {
        /// Inline navigation titles on iOS.
        func navigationBarTitleDisplayModeInline() -> some View {
            navigationBarTitleDisplayMode(.inline)
        }

        /// Marks the view as where a zoom navigation transition with `id` starts.
        func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
            matchedTransitionSource(id: id, in: namespace)
        }

        /// Zooms this destination out of the view marked with `zoomSource(id:in:)`.
        func zoomTransition(id: some Hashable, in namespace: Namespace.ID) -> some View {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        }

        /// The number pad with a decimal point.
        func decimalKeyboard() -> some View {
            keyboardType(.decimalPad)
        }

        /// Swipeable pages with dots.
        func pagedTabStyle() -> some View {
            tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

#else
    extension View {
        /// No-op on macOS.
        func navigationBarTitleDisplayModeInline() -> some View {
            self
        }

        /// No-op on macOS.
        func zoomSource(id _: some Hashable, in _: Namespace.ID) -> some View {
            self
        }

        /// No-op on macOS.
        func zoomTransition(id _: some Hashable, in _: Namespace.ID) -> some View {
            self
        }

        /// No-op on macOS.
        func decimalKeyboard() -> some View {
            self
        }

        /// No-op on macOS.
        func pagedTabStyle() -> some View {
            self
        }
    }
#endif
