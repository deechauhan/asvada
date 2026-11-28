import DesignSystem
import Model
import Storage
import SwiftUI

/// "Find places in my photos" (#64): says what it reads (where and when each photo was taken,
/// on the phone, nothing uploaded), asks for access, shows progress with Pause and Resume, and
/// then suggests the visits it found (#65): each with a few of its photos, to add to your
/// keepsakes in one tap or dismiss for good.
struct PhotoBackfillView: View {
    @Environment(\.modelContext) private var context
    @State private var backfill = PhotoBackfill()
    @State private var scan: Task<Void, Never>?
    /// Visits already added or dismissed, so they aren't suggested again.
    @State private var handled = VisitDecisions().handled

    private var pending: [VisitCluster] {
        Repository(context: context).pendingVisits(from: backfill.visits, handled: handled)
    }

    var body: some View {
        List {
            Section {
                Text(
                    """
                    Artifacts can look through your photos for where and when they were taken, to find \
                    places and countries you've already been. It reads only each photo's place and \
                    date, on this phone. Nothing is uploaded, and no pictures are copied. If you \
                    choose to share only some photos, it uses just those.
                    """,
                )
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
            }
            switch backfill.phase {
            case .idle:
                startSection(title: "Find my places")
            case .denied:
                deniedSection
            case .scanning:
                progressSection(isRunning: true)
            case .paused:
                progressSection(isRunning: false)
            case .finished:
                resultsSections
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("Photo places")
        .onDisappear { backfill.pause() }
    }

    private func startSection(title: String) -> some View {
        Section {
            Button(title, systemImage: "photo.on.rectangle.angled") {
                begin()
            }
            .accessibilityIdentifier("findPlacesButton")
        }
    }

    private var deniedSection: some View {
        Section {
            Text("Artifacts can't read your photos. You can allow it in Settings, then try again.")
                .typeToken(.body)
                .accessibilityIdentifier("photosDenied")
            if let settings = URL(string: "app-settings:") {
                Link("Open Settings", destination: settings)
            }
        }
    }

    private func progressSection(isRunning: Bool) -> some View {
        Section {
            ProgressView(value: backfill.progress)
                .accessibilityLabel("Looking through your photos")
                .accessibilityValue(BackfillText.progress(looked: backfill.looked, total: backfill.total))
            Text(BackfillText.progress(looked: backfill.looked, total: backfill.total))
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityIdentifier("scanProgress")
            if isRunning {
                Button("Pause", systemImage: "pause.fill") {
                    backfill.pause()
                }
                .accessibilityIdentifier("pauseScanButton")
            } else {
                Button("Resume", systemImage: "play.fill") {
                    begin()
                }
                .accessibilityIdentifier("resumeScanButton")
            }
        }
    }

    @ViewBuilder
    private var resultsSections: some View {
        Section {
            Text(BackfillText.summary(photos: backfill.looked, placed: backfill.placed, visits: backfill.visits.count))
                .typeToken(.body)
                .accessibilityIdentifier("scanSummary")
            Button("Scan again", systemImage: "arrow.clockwise") {
                backfill.reset()
                begin()
            }
        }
        if !pending.isEmpty {
            Section("You were in…") {
                ForEach(pending) { visit in
                    VisitSuggestionRow(
                        visit: visit,
                        thumbnails: { await backfill.thumbnails(for: visit) },
                        add: { add(visit) },
                        dismiss: { dismiss(visit) },
                    )
                }
            }
        } else if !backfill.visits.isEmpty {
            Section {
                Text("Nothing left to add: every visit found is in your keepsakes or dismissed.")
                    .typeToken(.callout)
                    .foregroundStyle(Palette.textSecondary.color)
                    .accessibilityIdentifier("noSuggestions")
            }
        }
        if !handled.isEmpty {
            Section {
                Button("Show dismissed visits again", systemImage: "eye") {
                    VisitDecisions().reset()
                    handled = []
                }
                .accessibilityIdentifier("resetDismissed")
            }
        }
    }

    /// Adds the visit to the keepsakes and doesn't suggest it again.
    private func add(_ visit: VisitCluster) {
        try? Repository(context: context).acceptVisit(visit)
        remember(visit)
    }

    private func dismiss(_ visit: VisitCluster) {
        remember(visit)
    }

    private func remember(_ visit: VisitCluster) {
        let decisions = VisitDecisions()
        decisions.markHandled(visit.id)
        handled = decisions.handled
    }

    /// Starts or resumes the scan in the background, so the screen stays live.
    private func begin() {
        scan?.cancel()
        scan = Task { await backfill.run() }
    }
}

/// The words the photo scan uses.
enum BackfillText {
    /// "Looked at 1,200 of 8,400 photos."
    static func progress(looked: Int, total: Int) -> String {
        guard total > 0 else { return "Getting ready…" }
        return "Looked at \(looked.formatted()) of \(total.formatted()) photos."
    }

    /// "Looked at 8,400 photos, 1,050 with a place. Found 6 visits."
    static func summary(photos: Int, placed: Int, visits: Int) -> String {
        let found = switch visits {
        case 0: "No visits found."
        case 1: "Found 1 visit."
        default: "Found \(visits) visits."
        }
        return "Looked at \(photos.formatted()) photos, \(placed.formatted()) with a place. \(found)"
    }

    /// "You were in Portugal".
    static func title(_ visit: VisitCluster) -> String {
        "You were in \(visit.countryName ?? "a place without a country")"
    }

    /// "12 Mar 2026", or "12 – 19 Mar 2026" for a visit over several days.
    static func dates(start: Date, end: Date, calendar: Calendar = .current) -> String {
        guard !calendar.isDate(start, inSameDayAs: end) else {
            return start.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return (start ..< end).formatted(.interval.day().month(.abbreviated).year())
    }

    /// "12 – 19 Mar 2026 · 30 photos".
    static func detail(_ visit: VisitCluster) -> String {
        "\(dates(start: visit.start, end: visit.end)) · \(photos(visit.photoCount))"
    }

    /// "1 photo", "30 photos".
    static func photos(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(count.formatted()) photos"
    }
}

/// One suggested visit: a few of its photos, where and when, and Add or Not now.
private struct VisitSuggestionRow: View {
    let visit: VisitCluster
    let thumbnails: () async -> [Data]
    let add: () -> Void
    let dismiss: () -> Void
    @State private var pictures: [PhotoThumbnail] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if !pictures.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(pictures) { picture in
                        picture.image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            .accessibilityHidden(true)
                    }
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(BackfillText.title(visit))
                    .typeToken(.headline)
                Text(BackfillText.detail(visit))
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .accessibilityElement(children: .combine)
            HStack {
                Button("Add", action: add)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.brand.color)
                    .accessibilityLabel("Add \(BackfillText.title(visit))")
                    .accessibilityIdentifier("visitAdd")
                Button("Not now", action: dismiss)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Dismiss \(BackfillText.title(visit))")
                    .accessibilityIdentifier("visitDismiss")
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("suggestedVisit")
        .task {
            pictures = await thumbnails().enumerated().map { index, data in
                PhotoThumbnail(id: "\(visit.id)-\(index)", data: data)
            }
        }
    }
}
