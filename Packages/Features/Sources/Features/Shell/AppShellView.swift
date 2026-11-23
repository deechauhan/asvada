import DesignSystem
import Storage
import SwiftData
import SwiftUI

/// The navigation skeleton: four tabs plus an always-available "Log" button that opens quick-log.
public struct AppShellView: View {
    /// Persisted so the app reopens on the tab you left it on.
    @AppStorage(AppTab.storageKey) private var selectedTabRaw = AppTab.timeline.rawValue
    @State private var isShowingQuickLog = false

    public init() {}

    public var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) {
                    screen(for: tab)
                }
            }
        }
        .tint(Palette.brand.color)
        .quickLogAccessory(logButton)
        .sheet(isPresented: $isShowingQuickLog) {
            QuickLogSheet()
        }
    }

    /// The global "+" — shown above the tab bar on every tab.
    private var logButton: some View {
        Button {
            isShowingQuickLog = true
        } label: {
            Label("Log something", systemImage: "plus")
                .typeToken(.headline)
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("quickLogButton")
        .accessibilityHint("Opens quick log")
    }

    private var selection: Binding<AppTab> {
        Binding(
            get: { AppTab.restored(from: selectedTabRaw) },
            set: { selectedTabRaw = $0.rawValue },
        )
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .timeline:
            PlaceholderScreen(tab: tab, message: "Everything you log will appear here, newest first.")
        case .collections:
            PlaceholderScreen(tab: tab, message: "Cafés, countries, films and your own collections.")
        case .map:
            PlaceholderScreen(tab: tab, message: "A collage of everywhere you've been.")
        case .settings:
            SettingsScreen()
        }
    }
}

#Preview {
    AppShellView()
        .modelContainer(PreviewData.container)
}

#if os(iOS)
    private extension View {
        /// iOS 26 tab-bar accessory: shown above the tab bar on every tab.
        func quickLogAccessory(_ button: some View) -> some View {
            tabViewBottomAccessory { button }
        }
    }

#else
    private extension View {
        /// macOS (package tests only): a bottom inset instead of the iOS tab-bar accessory.
        func quickLogAccessory(_ button: some View) -> some View {
            safeAreaInset(edge: .bottom) { button.padding() }
        }
    }
#endif
