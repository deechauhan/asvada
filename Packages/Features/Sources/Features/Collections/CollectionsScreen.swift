import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Every collection with its icon, colour and item count. Drag to reorder (Edit), swipe to hide;
/// hidden collections sit in their own section and can be shown again.
struct CollectionsScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)])
    private var collections: [ExperienceCollection]

    private var visible: [ExperienceCollection] {
        collections.filter { !$0.isHidden }
    }

    private var hidden: [ExperienceCollection] {
        collections.filter(\.isHidden)
    }

    @State private var isCreating = false
    @State private var editing: ExperienceCollection?

    private var repository: Repository {
        Repository(context: context)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(visible) { collection in
                        CollectionRow(collection: collection)
                            .swipeActions(edge: .leading) {
                                Button("Edit", systemImage: "pencil") {
                                    editing = collection
                                }
                                .tint(Palette.brand.color)
                            }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    editing = collection
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Hide", systemImage: "eye.slash") {
                                    setHidden(true, collection)
                                }
                                .tint(Palette.textSecondary.color)
                            }
                    }
                    .onMove { source, destination in
                        repository.reorder(visible, moving: source, to: destination)
                        save()
                    }
                }
                if !hidden.isEmpty {
                    Section("Hidden") {
                        ForEach(hidden) { collection in
                            CollectionRow(collection: collection)
                                .opacity(0.6)
                                .swipeActions(edge: .trailing) {
                                    Button("Show", systemImage: "eye") {
                                        setHidden(false, collection)
                                    }
                                    .tint(Palette.brand.color)
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .overlay {
                if collections.isEmpty {
                    ContentUnavailableView("No collections", systemImage: AppTab.collections.symbol)
                }
            }
            .navigationTitle(AppTab.collections.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New collection", systemImage: "plus") {
                        isCreating = true
                    }
                    .accessibilityIdentifier("newCollectionButton")
                }
            }
            .reorderButton()
            .sheet(isPresented: $isCreating) {
                CollectionEditor(mode: .create)
            }
            .sheet(item: $editing) { collection in
                CollectionEditor(mode: .edit(collection))
            }
        }
    }

    private func setHidden(_ isHidden: Bool, _ collection: ExperienceCollection) {
        withAnimation {
            repository.setHidden(isHidden, for: collection)
        }
        save()
    }

    private func save() {
        do {
            try repository.save()
        } catch {
            assertionFailure("Saving collections failed: \(error)")
        }
    }
}

/// One collection: tinted icon, name and how many items it holds.
struct CollectionRow: View {
    let collection: ExperienceCollection

    private var accent: CollectionAccent {
        collection.accent
    }

    private var count: Int {
        collection.items?.count ?? 0
    }

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: collection.icon)
                .font(.title3)
                .foregroundStyle(accent.token.color)
                .frame(width: 36, height: 36)
                .background(accent.token.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.small))
                .accessibilityHidden(true)
            Text(collection.name)
                .typeToken(.body)
                .foregroundStyle(Palette.textPrimary.color)
            Spacer()
            Text(count, format: .number)
                .typeToken(.callout)
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.name), \(count) \(count == 1 ? "item" : "items")")
        .accessibilityIdentifier("collection-\(collection.kind.rawValue)-\(collection.name)")
    }
}

#if os(iOS)
    private extension View {
        /// "Edit" puts the list in reorder mode.
        func reorderButton() -> some View {
            toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }

#else
    private extension View {
        /// macOS (package tests only): lists reorder by dragging without an edit mode.
        func reorderButton() -> some View {
            self
        }
    }
#endif

#Preview {
    CollectionsScreen()
        .modelContainer(PreviewData.container)
}
