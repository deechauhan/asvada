import DesignSystem
import Model
import Storage
import SwiftUI

/// Creates or edits a collection: name, icon, colour, rating mode, default view and (custom
/// collections only) item source. Editing a custom collection also offers a guarded delete.
struct CollectionEditor: View {
    enum Mode {
        case create
        case edit(ExperienceCollection)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State private var draft: CollectionDraft
    @State private var isConfirmingDelete = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _draft = State(initialValue: CollectionDraft())
        case let .edit(collection):
            _draft = State(initialValue: CollectionDraft(editing: collection))
        }
    }

    private var editing: ExperienceCollection? {
        if case let .edit(collection) = mode {
            return collection
        }
        return nil
    }

    private var repository: Repository {
        Repository(context: context)
    }

    static let icons = [
        "star.fill", "music.note", "figure.hiking", "book.fill", "gamecontroller.fill", "wineglass.fill",
        "mug.fill", "theatermasks.fill", "sportscourt.fill", "camera.fill", "leaf.fill", "tram.fill",
        "bed.double.fill", "paintpalette.fill", "birthday.cake.fill", "heart.fill",
    ]

    private var accent: CollectionAccent {
        CollectionAccent(rawValue: draft.accentName) ?? .custom
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    KeepsakePreview(name: draft.trimmedName, icon: draft.icon, accent: accent)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name, e.g. Concerts", text: $draft.name)
                        .accessibilityIdentifier("collectionNameField")
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.medium) {
                        ForEach(Self.icons, id: \.self) { icon in
                            iconButton(icon)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                Section("Colour") {
                    HStack {
                        ForEach(CollectionAccent.allCases) { option in
                            colourButton(option)
                        }
                    }
                }
                Section {
                    Picker("Rating", selection: $draft.ratingMode) {
                        ForEach(RatingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Default view", selection: $draft.defaultView) {
                        ForEach(ViewMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    if !draft.isBuiltIn {
                        Picker("Add items by", selection: $draft.itemSource) {
                            ForEach(CollectionDraft.customItemSources, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                }
                if let editing, !editing.isBuiltIn {
                    Section {
                        Button("Delete collection", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .accessibilityIdentifier("deleteCollectionButton")
                    } footer: {
                        Text("Built-in collections can be hidden from the Collections list instead.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle(editing == nil ? "New collection" : "Edit collection")
            .confirmationDialog(
                "Delete \(editing?.name ?? "collection")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible,
            ) {
                Button("Delete", role: .destructive, action: delete)
                    .accessibilityIdentifier("confirmDeleteButton")
            } message: {
                if let editing {
                    Text(repository.deletionImpact(of: editing).summary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("saveCollectionButton")
                }
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = draft.icon == icon
        return Button {
            draft.icon = icon
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .foregroundStyle(isSelected ? Palette.onBrand.color : accent.token.color)
                .background(
                    isSelected ? accent.token.color : accent.token.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Radius.small),
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colourButton(_ option: CollectionAccent) -> some View {
        let isSelected = draft.accentName == option.rawValue
        return Button {
            draft.accentName = option.rawValue
        } label: {
            Circle()
                .fill(option.token.color)
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Circle().stroke(Palette.textPrimary.color, lineWidth: 2).padding(-4)
                    }
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.colorName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        do {
            if let editing {
                try repository.update(editing, from: draft)
            } else {
                try repository.createCollection(from: draft)
            }
            dismiss()
        } catch {
            assertionFailure("Saving collection failed: \(error)")
        }
    }

    private func delete() {
        guard let editing else { return }
        do {
            try repository.deleteCollection(editing)
            dismiss()
        } catch {
            assertionFailure("Deleting collection failed: \(error)")
        }
    }
}

/// A live preview of the collection as a luggage-tag keepsake (the full keepsake kit
/// replaces this in #110).
private struct KeepsakePreview: View {
    let name: String
    let icon: String
    let accent: CollectionAccent

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent.token.color)
                .frame(width: 44, height: 44)
                .background(accent.token.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.keepsake))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Collection")
                    .typeToken(.ticketLabel)
                    .foregroundStyle(Palette.textSecondary.color)
                Text(name.isEmpty ? "Your collection" : name)
                    .typeToken(.title)
                    .foregroundStyle(name.isEmpty ? Palette.textSecondary.color : Palette.textPrimary.color)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.large)
        .background(Palette.keepsakePaper.color, in: RoundedRectangle(cornerRadius: Radius.keepsake))
        .shadow(color: Palette.textPrimary.color.opacity(0.12), radius: 10, y: 6)
        .paperTilt(-1.2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(name.isEmpty ? "untitled collection" : name)")
    }
}

#Preview("Create") {
    CollectionEditor(mode: .create)
        .modelContainer(PreviewData.container)
}
