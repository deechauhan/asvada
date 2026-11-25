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
    /// Between asking the sheet to close and it having gone: a sheet asked to open in that
    /// window is dropped, so the request waits for `onDismiss`.
    @State private var isClosingQuickLog = false
    @State private var pendingOpen: PendingQuickLog?
    /// The toast waiting for the sheet to finish closing.
    @State private var pendingToast: String?
    /// The entry just sealed: tapping the toast opens its details.
    @State private var sealedEntry: UUID?
    @State private var editingEntry: EditingEntry?
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
        .sheet(isPresented: $isShowingQuickLog, onDismiss: quickLogClosed) {
            QuickLogSheet(drawn: drawn) { words, entry in
                // The shell closes the sheet; the toast shows once it has really gone.
                pendingToast = words
                sealedEntry = entry
                isClosingQuickLog = true
                isShowingQuickLog = false
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                SavouredToast(text: toast) {
                    guard let sealedEntry else { return }
                    withAnimation(Motion.settle) { self.toast = nil }
                    editingEntry = EditingEntry(id: sealedEntry)
                }
                .padding(.top, Spacing.small)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(Motion.settle) { toast = nil }
        }
        .sheet(item: $editingEntry) { entry in
            EntryDetailsSheet(entryID: entry.id)
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
        guard !isClosingQuickLog else {
            pendingOpen = PendingQuickLog(drawing: collection)
            return
        }
        drawn = collection
        isShowingQuickLog = true
    }

    /// The sheet has finished closing (sealed, cancelled or swiped away): show the toast, and
    /// open quick-log again if the pill was tapped while it was on its way out.
    private func quickLogClosed() {
        isClosingQuickLog = false
        if let words = pendingToast {
            pendingToast = nil
            withAnimation(Motion.settle) { toast = words }
        }
        if let pending = pendingOpen {
            pendingOpen = nil
            openQuickLog(drawing: pending.drawing)
        }
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
            // A start chip draws its own blank; if that collection is hidden, the grid asks.
            JournalScreen(onSavour: { kind in openQuickLog(drawing: collections.first { $0.kind == kind }) })
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

/// The entry whose details are open.
private struct EditingEntry: Identifiable {
    let id: UUID
}

/// A quick-log asked for while the last one was still closing.
private struct PendingQuickLog {
    let drawing: ExperienceCollection?
}

/// The toast after sealing a keepsake: how long it took and which drawer it's in.
private struct SavouredToast: View {
    let text: String
    /// Opens the new entry's details.
    let addDetails: () -> Void

    var body: some View {
        Button(action: addDetails) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityHint("Add when, who with and tags")
        .accessibilityIdentifier("savouredToast")
    }

    private var content: some View {
        HStack(spacing: Spacing.small) {
            Text("ā")
                .font(.system(size: 13, weight: .heavy, design: .serif))
                .foregroundStyle(Palette.onBrand.color)
                .frame(width: 22, height: 22)
                .background(Palette.brand.color, in: Circle())
            Text(text)
                .typeToken(.callout)
                .foregroundStyle(Palette.textPrimary.color)
            Image(systemName: "square.and.pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.brand.color)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .glassEffect(.regular, in: Capsule())
    }
}
