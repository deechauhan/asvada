import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Names as chips with a field to type more: Return adds what you typed, and names used before
/// are suggested as you go (people you were with, tags).
struct NameTokensField: View {
    let title: String
    let prompt: String
    @Binding var names: [String]
    /// Names used before, the most used first.
    let known: [String]
    let id: String

    @State private var typed = ""

    private var suggestions: [String] {
        DetailNames.suggestions(known, prefix: typed, excluding: names, limit: typed.isEmpty ? 3 : 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
            if !names.isEmpty {
                FlowChips(items: names, systemImage: "xmark", id: "\(id)-chip") { name in
                    names.removeAll { $0 == name }
                }
            }
            TextField(prompt, text: $typed)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { add(typed) }
                .accessibilityIdentifier("\(id)Field")
            if !suggestions.isEmpty {
                FlowChips(items: suggestions, systemImage: "plus", id: "\(id)-suggestion") { name in
                    add(name)
                }
            }
        }
    }

    private func add(_ name: String) {
        names = DetailNames.cleaned(names + [name])
        typed = ""
    }
}

/// A wrapping row of small capsule buttons.
private struct FlowChips: View {
    let items: [String]
    let systemImage: String
    let id: String
    let action: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(items, id: \.self) { item in
                    Button {
                        action(item)
                    } label: {
                        Label(item, systemImage: systemImage)
                            .labelStyle(.titleAndIcon)
                            .typeToken(.callout)
                            .padding(.horizontal, Spacing.small)
                            .padding(.vertical, Spacing.xxs)
                            .background(Palette.surface.color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(id)-\(item)")
                }
            }
        }
    }
}

/// When it was (any day up to now), who you were with, and tags. Notes sit with the seal.
struct EntryDetailsFields: View {
    @Binding var date: Date
    @Binding var people: [String]
    @Binding var tags: [String]
    let knownPeople: [String]
    let knownTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            DatePicker("When", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                .accessibilityIdentifier("entryDate")
            NameTokensField(title: "Who with", prompt: "Add someone", names: $people, known: knownPeople, id: "people")
            NameTokensField(title: "Tags", prompt: "Add a tag", names: $tags, known: knownTags, id: "tags")
        }
    }
}

/// Details for an entry already sealed (from the toast): every change is saved as you make it.
struct EntryDetailsSheet: View {
    let entryID: UUID
    /// Offers "Delete this entry" when set: the sheet deletes it, closes, and hands what it held
    /// back so the screen underneath can offer Undo.
    var onDelete: ((DeletedEntry) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var details = EntryDetails()
    @State private var loaded = false
    /// Bumped when photos change, so the thumbnails are read again.
    @State private var photoChanges = 0

    private var repository: Repository {
        Repository(context: context)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    if let entry = repository.entry(id: entryID), let item = entry.item {
                        Text(item.name)
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary.color)
                        if let mode = item.collection?.ratingMode, mode.ratesEntries {
                            // How it landed, in halves (#37); saved as you go like the rest. Logs
                            // rate optionally, so a rating can be cleared there (#39).
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                RelishScale(rating: $details.rating, markSize: 24)
                                HStack {
                                    Text(details.rating.map { Relish.word(for: $0) ?? "" } ?? "Not rated yet")
                                        .font(.system(.callout, design: .serif).italic())
                                        .foregroundStyle(Palette.textSecondary.color)
                                        .accessibilityHidden(true)
                                    if mode == .log, details.rating != nil {
                                        Spacer(minLength: 0)
                                        Button("Clear rating") { details.rating = nil }
                                            .typeToken(.callout)
                                            .accessibilityIdentifier("clearRating")
                                    }
                                }
                            }
                        }
                    }
                    EntryDetailsFields(
                        date: $details.date,
                        people: $details.people,
                        tags: $details.tags,
                        knownPeople: repository.peopleNames(),
                        knownTags: repository.tagNames(),
                    )
                    TextField("A note to your future self", text: $details.notes, axis: .vertical)
                        .font(.system(.body, design: .serif).italic())
                        .lineLimit(1 ... 6)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("entryNotes")
                    EntryPhotosField(
                        thumbnails: keptPhotos,
                        onAdd: addPhotos,
                        onRemove: removePhoto,
                    )
                    Text("Changes are saved as you go.")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary.color)
                    if onDelete != nil {
                        Button("Delete this entry", systemImage: "trash", role: .destructive, action: delete)
                            .font(.callout)
                            .padding(.top, Spacing.large)
                            .accessibilityIdentifier("deleteEntryButton")
                    }
                }
                .padding(Spacing.large)
            }
            .background(Palette.background.color)
            .navigationTitle("Details")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("entryDetailsDone")
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: details) { _, newValue in
            guard loaded, let entry = repository.entry(id: entryID) else { return }
            try? repository.update(entry, with: newValue)
        }
    }

    /// The entry's kept photos (re-read whenever one is added or removed).
    private var keptPhotos: [PhotoThumbnail] {
        _ = photoChanges
        guard let entry = repository.entry(id: entryID) else { return [] }
        return repository.photos(of: entry).compactMap { photo in
            photo.thumbnailData.map { PhotoThumbnail(id: photo.id.uuidString, data: $0) }
        }
    }

    private func addPhotos(_ photos: [ProcessedPhoto]) {
        guard let entry = repository.entry(id: entryID) else { return }
        for photo in photos {
            repository.attach(photo, to: entry)
        }
        try? repository.save()
        photoChanges += 1
    }

    private func removePhoto(_ thumbnail: PhotoThumbnail) {
        guard let entry = repository.entry(id: entryID),
              let photo = (entry.photos ?? []).first(where: { $0.id.uuidString == thumbnail.id })
        else { return }
        repository.remove(photo)
        try? repository.save()
        photoChanges += 1
    }

    private func delete() {
        guard let onDelete, let entry = repository.entry(id: entryID) else { return }
        // Stop saving edits first: the entry is about to go.
        loaded = false
        guard let deleted = try? repository.deleteEntry(entry) else { return }
        dismiss()
        onDelete(deleted)
    }

    private func load() {
        guard !loaded else { return }
        if let entry = repository.entry(id: entryID) {
            details = EntryDetails(entry)
        }
        // Mark loaded after the first values land, so loading them isn't saved as an edit.
        Task { @MainActor in loaded = true }
    }
}
