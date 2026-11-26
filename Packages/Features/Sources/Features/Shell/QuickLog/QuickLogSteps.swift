import DesignSystem
import Geo
import Model
import Sources
import Storage
import SwiftData
import SwiftUI

/// Ranked repeat: "Still No. 2?" — yes skips ahead; re-rank duels again.
struct StillStep: View {
    let rank: Int
    let yes: () -> Void
    let reRank: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Still No. \(rank)?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            Button("Still No. \(rank)", action: yes)
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand.color)
                .accessibilityIdentifier("stillYes")
            Button("Rank it again", action: reRank)
                .accessibilityIdentifier("stillRerank")
        }
    }
}

/// Stars: five ā marks, rated in halves; the relish word prints under them. Lifting the finger
/// moves on; with VoiceOver, swipe up or down to rate, then Next.
struct RelishStep: View {
    let onRate: (Double) -> Void
    @State private var rating: Double?

    init(rating: Double?, onRate: @escaping (Double) -> Void) {
        self.onRate = onRate
        _rating = State(initialValue: rating)
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("How did it land?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            RelishScale(rating: $rating, onCommit: onRate)
            Text(rating.map { "\(Relish.word(for: $0) ?? "") · \(RelishInput.numeral($0))" } ?? "Tap or slide along the ā")
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityHidden(true)
                .accessibilityIdentifier("relishWord")
            Button("Next") {
                if let rating {
                    onRate(rating)
                }
            }
            .buttonStyle(.bordered)
            .tint(Palette.brand.color)
            .disabled(rating == nil)
            .accessibilityIdentifier("relishNext")
        }
    }
}

/// Log: when was it?
struct WhenStep: View {
    let times: String?
    let onPick: (LogWhen) -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("When?")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.textPrimary.color)
            HStack(spacing: Spacing.small) {
                ForEach(LogWhen.allCases) { when in
                    Button(when.title) { onPick(when) }
                        .buttonStyle(.bordered)
                        .tint(Palette.brand.color)
                        .accessibilityIdentifier("when-\(when.title)")
                }
            }
            if let times {
                Text(times)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
    }
}

/// Checklist: stamp it into the passport.
struct StampItStep: View {
    let onStamp: () -> Void

    var body: some View {
        Button(action: onStamp) {
            Label("Stamp", systemImage: "seal.fill")
                .typeToken(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.brand.color)
        .accessibilityIdentifier("stampItButton")
    }
}

/// The seal: an optional note to your future self, then hold the ā.
struct SealStep: View {
    let collection: ExperienceCollection
    @Binding var savouring: Savouring
    let onSeal: () -> Void
    @Environment(\.modelContext) private var context
    @State private var showsDetails = false

    private var summary: String? {
        if let position = savouring.rankPosition {
            return "No. \(position + 1) in \(collection.name)"
        }
        return Relish.word(for: savouring.rating)
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            if let summary {
                Text(summary)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Palette.brand.color)
                    .accessibilityIdentifier("quickLogSummary")
            }
            if collection.ratingMode == .log {
                // Logs can say how it landed too, but never have to (#39).
                VStack(spacing: Spacing.xs) {
                    Text("How did it land? (optional)")
                        .typeToken(.callout)
                        .foregroundStyle(Palette.textSecondary.color)
                    RelishScale(rating: $savouring.rating, markSize: 22)
                    if savouring.rating != nil {
                        Button("Clear rating") { savouring.rating = nil }
                            .typeToken(.caption)
                            .accessibilityIdentifier("clearRating")
                    }
                }
            }
            TextField("A note to your future self", text: $savouring.note, axis: .vertical)
                .font(.system(.body, design: .serif).italic())
                .lineLimit(1 ... 4)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("quickLogNote")
            Button {
                showsDetails.toggle()
            } label: {
                Label("When, who with, tags, photos", systemImage: showsDetails ? "chevron.down" : "chevron.right")
                    .typeToken(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.brand.color)
            .accessibilityValue(showsDetails ? "Shown" : "Hidden")
            .accessibilityIdentifier("quickLogDetails")
            if showsDetails {
                EntryDetailsFields(
                    date: $savouring.date,
                    people: $savouring.people,
                    tags: $savouring.tags,
                    knownPeople: Repository(context: context).peopleNames(),
                    knownTags: Repository(context: context).tagNames(),
                )
                if !collection.fields.isEmpty {
                    CustomFieldsForm(fields: collection.fields, values: $savouring.extra)
                }
                EntryPhotosField(
                    thumbnails: savouring.photos.enumerated().map { index, photo in
                        PhotoThumbnail(id: "picked-\(index)", data: photo.thumbnailData)
                    },
                    onAdd: { savouring.photos += $0 },
                    onRemove: { thumbnail in
                        if let index = Int(thumbnail.id.replacingOccurrences(of: "picked-", with: "")),
                           savouring.photos.indices.contains(index)
                        {
                            savouring.photos.remove(at: index)
                        }
                    },
                )
            }
            SealButton(action: onSeal)
            Text("Hold the ā to seal it")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
    }
}
