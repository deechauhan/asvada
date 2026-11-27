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
    /// `-inMemoryStore` keeps data off disk, `-disableTips` hides TipKit tips, `-sampleData` fills
    /// the built-ins with sample keepsakes (only together with `-inMemoryStore`), `-countryPicker`
    /// opens the country picker on its own, `-skipOnboarding` keeps first-launch onboarding away,
    /// `-cabinetMidRoll` stops the turning cabinet between two drawers (for screenshots),
    /// `-stressItems N` adds N ranked cafés (with `-inMemoryStore`, for performance runs),
    /// `-samplePlaces` searches a fixed set of London places instead of Apple Maps,
    /// `-fakeAuthenticator` passes the app lock without Face ID (the simulator has none).
    private let arguments = ProcessInfo.processInfo.arguments
    private let container: ModelContainer

    init() {
        if arguments.contains("-resetState") {
            UserDefaults.standard.removeObject(forKey: AppTab.storageKey)
            UserDefaults.standard.removeObject(forKey: "seal.hasLearnedHold")
            UserDefaults.standard.removeObject(forKey: "onboarding.completed")
            UserDefaults.standard.removeObject(forKey: "cabinet.front")
            AppLockDefaults.reset()
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
        // Sample keepsakes for screenshots; never written to the real store.
        if arguments.contains("-sampleData"), arguments.contains("-inMemoryStore") {
            try? PreviewData.fillBuiltIns(Repository(context: container.mainContext))
        }
        // Extra keepsakes for performance runs (ADR-0004), also only in memory.
        if arguments.contains("-inMemoryStore"),
           let flag = arguments.firstIndex(of: "-stressItems"),
           arguments.indices.contains(flag + 1),
           let count = Int(arguments[flag + 1])
        {
            try? PreviewData.addStressItems(count, to: Repository(context: container.mainContext))
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if arguments.contains("-designCatalog") {
                    DesignCatalogView()
                } else if arguments.contains("-keepsakeGallery") {
                    KeepsakeGallery()
                } else if arguments.contains("-countryPicker") {
                    CountryPickerScreen()
                } else if arguments.contains("-samplePlaces") {
                    RootView().searchingSamplePlaces()
                } else {
                    RootView()
                }
            }
            .preferredColorScheme(arguments.contains("-forceDarkMode") ? .dark : nil)
        }
        .modelContainer(container)
    }
}
