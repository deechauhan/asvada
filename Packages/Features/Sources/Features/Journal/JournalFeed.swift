import DesignSystem
import Model
import SwiftUI

/// The Journal once there are entries: every keepsake you've sealed, newest first, a month at a
/// time under an italic masthead. Months and cards are built lazily, so a feed of thousands scrolls
/// as smoothly as a short one.
struct JournalFeed: View {
    let months: [JournalMonth]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.xl, pinnedViews: []) {
            ForEach(months) { month in
                Section {
                    ForEach(Array(month.entries.enumerated()), id: \.element.id) { index, entry in
                        if let item = entry.item, let collection = item.collection {
                            NavigationLink {
                                ItemDetailScreen(item: item)
                            } label: {
                                EntryCard(entry: entry, item: item, collection: collection)
                            }
                            .buttonStyle(.plain)
                            .paperTilt(index.isMultiple(of: 2) ? -1 : 1)
                            .accessibilityIdentifier("journalEntry")
                        }
                    }
                } header: {
                    MonthMasthead(month: month)
                }
            }
        }
    }
}

/// "November", with the year once it isn't this year's, and what the month held under a macron.
struct MonthMasthead: View {
    let month: JournalMonth

    private var title: String {
        let sameYear = Calendar.current.isDate(month.start, equalTo: .now, toGranularity: .year)
        return month.start.formatted(sameYear ? .dateTime.month(.wide) : .dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .typeToken(.masthead)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Text(month.summary)
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
            MacronBar(progress: 0.12, height: 3)
                .frame(width: 56)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("journalMonth")
    }
}

/// One sealed keepsake in the feed: the item drawn as its collection's keepsake, how it landed,
/// and the photos taken with it.
struct EntryCard: View {
    let entry: Entry
    let item: Item
    let collection: ExperienceCollection

    private var landed: String? {
        guard let rating = entry.rating, let word = Relish.word(for: rating) else { return nil }
        return "\(word) \(RelishInput.numeral(rating))"
    }

    private var thumbnails: [PhotoThumbnail] {
        let all = (entry.photos ?? []).compactMap { photo in
            photo.thumbnailData.map { PhotoThumbnail(id: photo.id.uuidString, data: $0) }
        }
        return Array(all.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ItemKeepsake(item: item, collection: collection, entry: entry)
                .frame(maxWidth: .infinity)
            if let landed {
                Text(landed)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
                    .padding(.horizontal, Spacing.small)
            }
            if !thumbnails.isEmpty {
                HStack(spacing: Spacing.small) {
                    ForEach(thumbnails) { thumbnail in
                        thumbnail.image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, Spacing.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(item.name)")
    }
}
