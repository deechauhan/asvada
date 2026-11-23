import Foundation
import SwiftUI

/// The app's root view. On first launch the onboarding flow covers it until it's finished or
/// skipped (UI tests pass `-skipOnboarding`, or `-onboarding` to see it).
public struct RootView: View {
    @AppStorage(OnboardingStore.completedKey) private var hasOnboarded = false
    private let skipsOnboarding = ProcessInfo.processInfo.arguments.contains("-skipOnboarding")

    public init() {}

    private var showsOnboarding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded && !skipsOnboarding },
            set: { isShown in
                if !isShown {
                    hasOnboarded = true
                }
            },
        )
    }

    public var body: some View {
        AppShellView()
            .onboardingCover(isPresented: showsOnboarding) {
                OnboardingFlow { hasOnboarded = true }
            }
    }
}

#if os(iOS)
    private extension View {
        func onboardingCover(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
            fullScreenCover(isPresented: isPresented, content: content)
        }
    }

#else
    private extension View {
        /// macOS (package tests only) has no full-screen cover; a sheet will do.
        func onboardingCover(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
            sheet(isPresented: isPresented, content: content)
        }
    }
#endif

#Preview {
    RootView()
}
