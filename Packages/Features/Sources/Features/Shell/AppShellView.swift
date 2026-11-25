import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// The Keepsakes shell: Journal, Collections and Atlas, plus an always-available glass
/// "Savour something" pill. Tap it for quick-log; hold it and a hand of blank keepsakes fans out
/// over the screen to draw from.
public struct AppShellView: View {
    /// Persisted so the app reopens on the tab you left it on.
    @AppStorage(AppTab.storageKey) private var selectedTabRaw = AppTab.journal.rawValue
    @Query(
        filter: #Predicate<ExperienceCollection> { !$0.isHidden },
        sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)],
    )
    private var collections: [ExperienceCollection]
    @State private var isShowingQuickLog = false
    /// The blank drawn from the hand, if quick-log opened by drawing.
    @State private var drawn: ExperienceCollection?
    @State private var hand = HandState()
    @State private var pillFrame = PillFrame()
    /// "Savoured in 6.4 s · it's in your Cafés drawer", for a few seconds after sealing.
    @State private var toast: String?

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
        .quickLogAccessory(pill)
        .overlay { handOverlay }
        .overlay {
            PillPressCatcher(
                collections: collections,
                frame: pillFrame,
                hand: $hand,
                onTap: { openQuickLog(drawing: nil) },
                onDraw: { openQuickLog(drawing: $0) },
            )
        }
        .sheet(isPresented: $isShowingQuickLog) {
            QuickLogSheet(drawn: drawn) { words in
                withAnimation(Motion.settle) { toast = words }
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                SavouredToast(text: toast)
                    .padding(.top, Spacing.small)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(Motion.settle) { toast = nil }
        }
    }

    /// The savour pill — shown above the tab bar on every tab.
    private var pill: some View {
        SavourPill(
            collections: collections,
            frame: pillFrame,
            onTap: { openQuickLog(drawing: nil) },
            onDraw: { openQuickLog(drawing: $0) },
        )
    }

    /// The hand fans out over everything, centred on the pill.
    @ViewBuilder
    private var handOverlay: some View {
        if hand.isShown {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                HandOfBlanks(collections: Array(collections.prefix(HandLayout.maximumCount)), selection: hand.selection)
                    .position(x: pillFrame.centre.x - frame.minX, y: pillFrame.centre.y - frame.minY)
            }
            .ignoresSafeArea()
            .background(Palette.background.color.opacity(0.35).ignoresSafeArea())
            // The press that brought the hand out keeps tracking on the catcher over the pill.
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func openQuickLog(drawing collection: ExperienceCollection?) {
        drawn = collection
        isShowingQuickLog = true
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
            JournalScreen(onSavour: { openQuickLog(drawing: nil) })
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
        func quickLogAccessory(_ pill: some View) -> some View {
            tabViewBottomAccessory { pill }
        }
    }

#else
    private extension View {
        /// macOS (package tests only): a bottom inset instead of the iOS tab-bar accessory.
        func quickLogAccessory(_ pill: some View) -> some View {
            safeAreaInset(edge: .bottom) { pill.padding() }
        }
    }
#endif

/// The toast after sealing a keepsake: how long it took and which drawer it's in.
private struct SavouredToast: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("ā")
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.onBrand.color)
                .frame(width: 22, height: 22)
                .background(Palette.brand.color, in: Circle())
            Text(text)
                .typeToken(.callout)
                .foregroundStyle(Palette.textPrimary.color)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("savouredToast")
    }
}
