import DesignSystem
import Storage
import SwiftData
import SwiftUI

/// The Keepsakes shell: Journal, Collections and Atlas, plus an always-available glass
/// "Savour something" pill that opens quick-log.
public struct AppShellView: View {
    /// Persisted so the app reopens on the tab you left it on.
    @AppStorage(AppTab.storageKey) private var selectedTabRaw = AppTab.journal.rawValue
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

    /// The savour pill — shown above the tab bar on every tab.
    private var logButton: some View {
        Button {
            isShowingQuickLog = true
        } label: {
            HStack(spacing: Spacing.small) {
                Text("ā")
                    .font(.system(size: 15, weight: .heavy, design: .serif))
                    .foregroundStyle(Palette.onBrand.color)
                    .frame(width: 26, height: 26)
                    .background(Palette.brand.color, in: Circle())
                    .accessibilityHidden(true)
                Text("Savour something")
                    .typeToken(.headline)
                    .foregroundStyle(Palette.textPrimary.color)
            }
            .frame(maxWidth: .infinity)
        }
        .tint(Palette.brand.color)
        .accessibilityLabel("Savour something")
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
        case .journal:
            JournalScreen(onSavour: { isShowingQuickLog = true })
        case .collections:
            CollectionsScreen()
        case .atlas:
            PlaceholderScreen(tab: tab, message: "A collage of everywhere you've been. Your countries will fill with ink here.")
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
