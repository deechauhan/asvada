import DesignSystem
import Features
import SwiftUI

@main
struct AsvadaApp: App {
    /// Launch arguments used by UI tests and for quick manual checks:
    /// `-resetState` clears restored UI state, `-designCatalog` opens the design catalogue,
    /// `-forceDarkMode` forces dark appearance.
    private let arguments = ProcessInfo.processInfo.arguments

    init() {
        if arguments.contains("-resetState") {
            UserDefaults.standard.removeObject(forKey: AppTab.storageKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if arguments.contains("-designCatalog") {
                    DesignCatalogView()
                } else {
                    RootView()
                }
            }
            .preferredColorScheme(arguments.contains("-forceDarkMode") ? .dark : nil)
        }
    }
}
