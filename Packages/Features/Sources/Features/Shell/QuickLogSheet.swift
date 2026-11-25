import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Quick-log. Opened by a tap on the savour pill it lays the hand of blanks out as a grid, with
/// "Again?" chips for the latest things savoured (they skip straight to sealing); opened by
/// drawing from the hand it starts on the drawn blank. Then: what was it, the savour step for its
/// collection, and the seal. The print head (#154) will print guesses onto the blank.
struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(
        filter: #Predicate<ExperienceCollection> { !$0.isHidden },
        sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)],
    )
    private var collections: [ExperienceCollection]
    @State private var drawn: ExperienceCollection?
    /// Something to savour again, from an "Again?" chip.
    @State private var again: Item?
    /// When the sheet opened, for the "Savoured in 6.4 s" toast.
    @State private var startedAt = Date.now
    /// Called with the toast's words once a keepsake is sealed; the presenter closes the sheet.
    var onSealed: (String) -> Void = { _ in }

    init(drawn: ExperienceCollection? = nil, onSealed: @escaping (String) -> Void = { _ in }) {
        _drawn = State(initialValue: drawn)
        self.onSealed = onSealed
    }

    /// The latest few things savoured, newest first, one per item.
    private var recentItems: [Item] {
        let entries = (try? Repository(context: context).recentEntries(limit: 20)) ?? []
        var seen = Set<UUID>()
        return Array(entries.compactMap(\.item).filter { seen.insert($0.id).inserted }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let drawn {
                    QuickLogFlowView(
                        collection: drawn,
                        again: again,
                        startedAt: startedAt,
                        onSealed: onSealed,
                    )
                    .id(drawn.id)
                } else {
                    hand
                }
            }
            .background(Palette.background.color)
            .navigationTitle(drawn?.savourPhrase ?? "What did you savour?")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if drawn != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Draw another") {
                            withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) {
                                drawn = nil
                                again = nil
                            }
                        }
                        .accessibilityIdentifier("drawAnotherButton")
                    }
                }
            }
        }
        // The hand fits half a screen; once a blank is drawn the flow needs the whole sheet, so
        // the note and the seal are never below the fold.
        .presentationDetents(drawn == nil ? [.medium, .large] : [.large])
    }

    /// The tap path: the same blanks as the hand, as a grid, plus "Again?" chips.
    private var hand: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                if !recentItems.isEmpty {
                    AgainChips(items: recentItems) { item in
                        again = item
                        draw(item.collection)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Spacing.medium)], spacing: Spacing.large) {
                    ForEach(collections) { collection in
                        Button {
                            draw(collection)
                        } label: {
                            VStack(spacing: Spacing.small) {
                                BlankKeepsake(collection: collection)
                                Text(collection.name)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.textPrimary.color)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(collection.savourPhrase)
                        .accessibilityIdentifier("blank-\(collection.kind.rawValue)-\(collection.name)")
                    }
                }
            }
            .padding(Spacing.large)
        }
    }

    private func draw(_ collection: ExperienceCollection?) {
        guard let collection else { return }
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) {
            drawn = collection
        }
    }
}

/// "Again?" chips: the latest things savoured, one tap from logging them again.
private struct AgainChips: View {
    let items: [Item]
    let draw: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Again?")
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) {
                    ForEach(items) { item in
                        Button(item.name) { draw(item) }
                            .buttonStyle(.bordered)
                            .tint(item.collection?.accent.token.color ?? Palette.brand.color)
                            .accessibilityLabel("Again: \(item.name)")
                    }
                }
            }
        }
    }
}
