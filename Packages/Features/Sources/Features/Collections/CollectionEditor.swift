import DesignSystem
import Model
import Storage
import SwiftUI

/// Form for a custom collection: name, icon, colour, rating mode, default view and item source.
struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CollectionDraft()

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
                    Picker("Add items by", selection: $draft.itemSource) {
                        ForEach(CollectionDraft.customItemSources, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .navigationTitle("New collection")
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
            try Repository(context: context).createCollection(from: draft)
            dismiss()
        } catch {
            assertionFailure("Creating collection failed: \(error)")
        }
    }
}

#Preview {
    NewCollectionSheet()
        .modelContainer(PreviewData.container)
}
