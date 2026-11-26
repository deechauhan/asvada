import DesignSystem
import Storage
import SwiftUI

/// "Find places in my photos" (#64): says what it reads (where and when each photo was taken,
/// on the phone, nothing uploaded), asks for access, shows progress with Pause and Resume, and
/// lists the visits it found. Adding them to your keepsakes comes with the suggestions inbox (#65).
struct PhotoBackfillView: View {
    @State private var backfill = PhotoBackfill()
    @State private var scan: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                Text(
                    """
                    Asvada can look through your photos for where and when they were taken, to find \
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
            Text("Asvada can't read your photos. You can allow it in Settings, then try again.")
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
        if !backfill.visits.isEmpty {
            Section("Places you've been") {
                ForEach(backfill.visits) { visit in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(BackfillText.place(visit))
                            .typeToken(.headline)
                        Text(BackfillText.detail(visit))
                            .typeToken(.caption)
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("foundVisit")
                }
            }
        }
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

    /// The country a visit was in, or a plain "A place" when it was somewhere without one.
    static func place(_ visit: VisitCluster) -> String {
        visit.countryName ?? "Somewhere without a country"
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
