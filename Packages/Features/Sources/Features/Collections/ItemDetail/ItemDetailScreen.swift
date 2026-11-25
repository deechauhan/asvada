import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// One thing's page: its keepsake, where it ranks or how it landed on average, how often, a strip
/// of every photo, and every entry newest first. Tap an entry for its details; swipe it left (or
/// use Delete in its details, or the VoiceOver action) to delete it, with a few seconds to undo.
/// Reached from an open drawer for now; lifting the front card out of the riffle (#156) will
/// open it too.
struct ItemDetailScreen: View {
    let item: Item
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var editing: EditedEntry?
    /// The entry just deleted, while it can still be put back.
    @State private var undo: DeletedEntry?
    /// Bumped on every delete, for the tear haptic.
    @State private var deletions = 0

    /// How long "Undo" stays up (longer with VoiceOver, to reach it).
    private var undoWindow: Duration {
        voiceOver ? .seconds(12) : .seconds(6)
    }

    private var collection: ExperienceCollection? {
        item.collection
    }

    private var repository: Repository {
        Repository(context: context)
    }

    private var rank: Int? {
        guard let collection else { return nil }
        return repository.ranking(of: collection).firstIndex { $0.id == item.id }
    }

    private var photos: [Photo] {
        item.entriesNewestFirst.flatMap { repository.photos(of: $0) }
    }

    var body: some View {
        List {
            Group {
                if let collection {
                    ItemKeepsake(item: item, collection: collection, rank: rank.map { $0 + 1 })
                        .frame(maxWidth: .infinity)
                    header(collection)
                }
                if !photos.isEmpty {
                    PhotoStrip(photos: photos)
                }
                ForEach(item.entriesNewestFirst) { entry in
                    entryRow(entry)
                }
            }
            .listRowInsets(EdgeInsets(top: Spacing.small, leading: Spacing.large, bottom: Spacing.small, trailing: Spacing.large))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("itemDetail")
        .overlay(alignment: .top) {
            if let undo {
                UndoToast(deleted: undo) { putBack(undo) }
                    .padding(.top, Spacing.small)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: undoWindow)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) { undo = nil }
        }
        .haptic(.tear, trigger: deletions)
        .sheet(item: $editing) { entry in
            EntryDetailsSheet(entryID: entry.id, onDelete: offerUndo)
        }
    }

    private func entryRow(_ entry: Entry) -> some View {
        Button {
            editing = EditedEntry(id: entry.id)
        } label: {
            EntryRow(entry: entry)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("itemEntry")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("deleteEntry")
        }
    }

    private func delete(_ entry: Entry) {
        guard let deleted = try? repository.deleteEntry(entry) else { return }
        offerUndo(deleted)
    }

    private func offerUndo(_ deleted: DeletedEntry) {
        deletions += 1
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) { undo = deleted }
        AccessibilityNotification.Announcement(UndoToast.words(for: deleted)).post()
    }

    private func putBack(_ deleted: DeletedEntry) {
        _ = try? repository.restore(deleted)
        withAnimation(Motion.animation(Motion.settle, reduceMotion: reduceMotion)) { undo = nil }
    }

    private func header(_ collection: ExperienceCollection) -> some View {
        let stats = ItemStats(item: item, collection: collection, rank: rank)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            if let rankLine = stats.rankLine {
                Text(rankLine)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.brand.color)
                    .accessibilityIdentifier("itemRank")
            }
            if let relish = stats.relish {
                Text(relish)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.brand.color)
                    .accessibilityIdentifier("itemRelish")
            }
            Text(stats.countLine)
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityIdentifier("itemCount")
            if let place = item.placeAddress {
                Label(place, systemImage: "mappin")
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
    }
}

/// "Deleted your 12 Nov visit · Undo", over the top of the page for a few seconds.
private struct UndoToast: View {
    let deleted: DeletedEntry
    let onUndo: () -> Void

    static func words(for deleted: DeletedEntry) -> String {
        "Deleted \(deleted.date.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(Self.words(for: deleted))
                .typeToken(.callout)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityIdentifier("undoToast")
            Button("Undo", action: onUndo)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Palette.brand.color)
                .accessibilityIdentifier("undoDelete")
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .glassEffect(.regular, in: Capsule())
    }
}

/// The entry whose details are open.
private struct EditedEntry: Identifiable {
    let id: UUID
}

/// One encounter: when, how it landed, who with, and the start of the note.
private struct EntryRow: View {
    let entry: Entry

    private var subtitle: String {
        var parts: [String] = []
        if let word = Relish.word(for: entry.rating) {
            parts.append(word)
        }
        let people = (entry.people ?? []).map(\.name).sorted()
        if !people.isEmpty {
            parts.append("with \(people.formatted(.list(type: .and)))")
        }
        if let photos = entry.photos, !photos.isEmpty {
            parts.append(photos.count == 1 ? "1 photo" : "\(photos.count) photos")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Palette.textPrimary.color)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textPrimary.color)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
    }
}

/// Every photo of the thing, newest entry first.
private struct PhotoStrip: View {
    let photos: [Photo]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                ForEach(photos) { photo in
                    if let data = photo.thumbnailData {
                        PhotoThumbnail(id: photo.id.uuidString, data: data).image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            .accessibilityLabel(Self.label(for: photo))
                    }
                }
            }
        }
        .accessibilityIdentifier("itemPhotos")
    }

    private static func label(for photo: Photo) -> String {
        guard let takenAt = photo.takenAt else { return "Photo" }
        return "Photo, \(takenAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
