import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// One thing's page: its keepsake, where it ranks or how it landed on average, how often, a strip
/// of every photo, and every entry newest first (tap one for its details). Reached from an open
/// drawer for now; lifting the front card out of the riffle (#156) will open it too.
struct ItemDetailScreen: View {
    let item: Item
    @Environment(\.modelContext) private var context
    @State private var editing: EditedEntry?

    private var collection: ExperienceCollection? {
        item.collection
    }

    private var rank: Int? {
        guard let collection else { return nil }
        return Repository(context: context).ranking(of: collection).firstIndex { $0.id == item.id }
    }

    private var photos: [Photo] {
        item.entriesNewestFirst.flatMap { Repository(context: context).photos(of: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                if let collection {
                    ItemKeepsake(item: item, collection: collection, rank: rank.map { $0 + 1 })
                        .frame(maxWidth: .infinity)
                    header(collection)
                }
                if !photos.isEmpty {
                    PhotoStrip(photos: photos)
                }
                entries
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("itemDetail")
        .sheet(item: $editing) { entry in
            EntryDetailsSheet(entryID: entry.id)
        }
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

    private var entries: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ForEach(item.entriesNewestFirst) { entry in
                Button {
                    editing = EditedEntry(id: entry.id)
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("itemEntry")
            }
        }
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
