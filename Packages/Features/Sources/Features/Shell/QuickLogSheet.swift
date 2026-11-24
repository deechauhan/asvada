import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Quick-log. Opened by a tap on the savour pill it lays the hand of blanks out as a grid, with
/// "Again?" chips for the latest things savoured; opened by drawing from the hand it starts on
/// the drawn blank. The print head (suggestions printed onto the blank) and the rest of the flow
/// follow in #154 and #31.
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

    init(drawn: ExperienceCollection? = nil) {
        _drawn = State(initialValue: drawn)
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
                    DrawnBlank(collection: drawn) {
                        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) { self.drawn = nil }
                    }
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
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The tap path: the same blanks as the hand, as a grid, plus "Again?" chips.
    private var hand: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                if !recentItems.isEmpty {
                    AgainChips(items: recentItems) { item in
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

/// The blank just drawn: it lands big, waiting for the print head.
private struct DrawnBlank: View {
    let collection: ExperienceCollection
    let drawAnother: () -> Void

    @State private var landed = 0

    var body: some View {
        VStack(spacing: Spacing.large) {
            BlankKeepsake(collection: collection, isLifted: true)
                .scaleEffect(2.2)
                .frame(width: BlankKeepsake.size.width * 2.2, height: BlankKeepsake.size.height * 2.2)
                .thunk(trigger: landed)
                .padding(.top, Spacing.xl)
            Text(collection.name)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            Button("Draw another", action: drawAnother)
                .buttonStyle(.bordered)
                .tint(Palette.brand.color)
                .accessibilityIdentifier("drawAnotherButton")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear { landed += 1 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drawnBlank")
    }
}
