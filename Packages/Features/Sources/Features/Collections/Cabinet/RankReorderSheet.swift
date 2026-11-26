import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// The arithmetic of moving one row in a ranked list.
enum RankReorder {
    /// Where a row ends up after `onMove(fromOffsets:toOffset:)` moves it from `source` to the gap
    /// at `destination` (the gap index counts the row itself, so moving down lands one earlier).
    static func position(movingFrom source: Int, toOffset destination: Int) -> Int {
        destination > source ? destination - 1 : destination
    }

    /// The place `delta` rows from `index`, or nil past either end.
    static func step(_ index: Int, by delta: Int, count: Int) -> Int? {
        let target = index + delta
        return (0 ..< count).contains(target) ? target : nil
    }
}

/// Re-orders a ranked drawer by hand: drag a row by its handle, or tap its up and down arrows
/// (the same move, for VoiceOver and Switch Control). Each move re-scores only the moved item
/// (`Repository.place`) and is saved at once.
struct RankReorderSheet: View {
    let collection: ExperienceCollection
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var order: [Item] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, item in
                    row(item, index: index)
                }
                .onMove { source, destination in
                    guard let from = source.first else { return }
                    move(from: from, to: RankReorder.position(movingFrom: from, toOffset: destination))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .alwaysEditing()
            .navigationTitle("Re-order")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("reorderDone")
                }
            }
            .onAppear {
                order = Repository(context: context).ranking(of: collection)
            }
        }
    }

    private func row(_ item: Item, index: Int) -> some View {
        HStack(spacing: Spacing.medium) {
            Text("No. \(index + 1)")
                .font(.system(.callout, design: .serif, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.brand.color)
                .frame(width: 56, alignment: .leading)
            Text(item.name)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
            Spacer(minLength: 0)
            stepButton("Move up", symbol: "chevron.up", item: item, index: index, delta: -1)
            stepButton("Move down", symbol: "chevron.down", item: item, index: index, delta: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No. \(index + 1), \(item.name)")
        .accessibilityIdentifier("rankRow-\(item.name)")
    }

    private func stepButton(_ title: String, symbol: String, item: Item, index: Int, delta: Int) -> some View {
        Button {
            if let target = RankReorder.step(index, by: delta, count: order.count) {
                withAnimation(.snappy) { move(from: index, to: target) }
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.borderless)
        .disabled(RankReorder.step(index, by: delta, count: order.count) == nil)
        .accessibilityLabel("\(title), \(item.name)")
        .accessibilityIdentifier("\(delta < 0 ? "moveUp" : "moveDown")-\(item.name)")
    }

    private func move(from source: Int, to target: Int) {
        guard order.indices.contains(source), order.indices.contains(target), source != target else { return }
        let item = order.remove(at: source)
        order.insert(item, at: target)
        let repository = Repository(context: context)
        repository.place(item, at: target, in: collection)
        try? repository.save()
    }
}

#if os(iOS)
    private extension View {
        /// Drag handles always showing, as a re-order screen should.
        func alwaysEditing() -> some View {
            environment(\.editMode, .constant(.active))
        }
    }

#else
    private extension View {
        /// macOS (package tests only) has no edit mode.
        func alwaysEditing() -> some View {
            self
        }
    }
#endif
