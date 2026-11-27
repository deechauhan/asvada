import SwiftUI

extension View {
    /// Puts the lock's cover in a window of its own, above everything, sheets included: an
    /// overlay would leave an open sheet (quick-log, Settings) readable behind it.
    func appLockWindow(_ model: AppLockModel) -> some View {
        modifier(AppLockWindowModifier(model: model))
    }
}

#if os(iOS)
    import UIKit

    private struct AppLockWindowModifier: ViewModifier {
        let model: AppLockModel
        @State private var controller = AppLockWindowController()

        func body(content: Content) -> some View {
            content
                .onChange(of: model.showsCover, initial: true) { controller.update(showsCover: model.showsCover, model: model) }
        }
    }

    /// Owns the window the cover lives in: up while the app is locked or out of front, gone after.
    @MainActor
    private final class AppLockWindowController {
        private var window: UIWindow?

        func update(showsCover: Bool, model: AppLockModel) {
            if showsCover {
                show(model)
            } else {
                window?.isHidden = true
                window = nil
            }
        }

        private func show(_ model: AppLockModel) {
            guard window == nil,
                  let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
            else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: AppLockCover(model: model))
            window.isHidden = false
            self.window = window
            // VoiceOver moves to the lock screen instead of reading the app behind it.
            UIAccessibility.post(notification: .screenChanged, argument: window)
        }
    }

#else
    /// macOS (package tests only) has no lock window.
    private struct AppLockWindowModifier: ViewModifier {
        let model: AppLockModel

        func body(content: Content) -> some View {
            content
        }
    }
#endif
