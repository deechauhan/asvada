import DesignSystem
import Features
import SwiftUI

@main
struct AsvadaApp: App {
    /// Launch arguments used by UI tests and for quick manual checks.
    private let arguments = ProcessInfo.processInfo.arguments

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
