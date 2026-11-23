import DesignSystem
import Features
import Storage
import SwiftData
import SwiftUI
import TipKit

@main
struct AsvadaApp: App {
    /// Launch arguments used by UI tests and for quick manual checks:
    /// `-resetState` clears restored UI state, `-designCatalog` opens the design catalogue,
    /// `-keepsakeGallery` opens the keepsake gallery, `-forceDarkMode` forces dark appearance,
    /// `-inMemoryStore` keeps data off disk, `-disableTips` hides TipKit tips.
    private let arguments = ProcessInfo.processInfo.arguments
    private let container: ModelContainer

    init() {
        if arguments.contains("-resetState") {
            UserDefaults.standard.removeObject(forKey: AppTab.storageKey)
            UserDefaults.standard.removeObject(forKey: "seal.hasLearnedHold")
        }
        do {
            container = try AsvadaStore.makeContainer(arguments.contains("-inMemoryStore") ? .inMemory : .standard)
        } catch {
            // Without a store the app can't do anything useful; surface the reason clearly.
            fatalError("Could not open the Asvada data store: \(error)")
        }
        // Tips teach gestures like "hold the ā"; UI tests turn them off so popovers don't cover controls.
        if !arguments.contains("-disableTips") {
            try? Tips.configure([.displayFrequency(.immediate)])
        }
        do {
            try BuiltInCollections.seedIfNeeded(in: container.mainContext)
        } catch {
            // Not fatal: the app works without built-ins and seeding retries on next launch.
            print("Seeding built-in collections failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if arguments.contains("-designCatalog") {
                    DesignCatalogView()
                } else if arguments.contains("-keepsakeGallery") {
                    KeepsakeGallery()
                } else {
                    RootView()
                }
            }
            .preferredColorScheme(arguments.contains("-forceDarkMode") ? .dark : nil)
        }
        .modelContainer(container)
    }
}
