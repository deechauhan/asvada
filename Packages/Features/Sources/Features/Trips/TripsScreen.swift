import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// The trips list (#66): a trip groups a flight, restaurants, cafés and the rest into one page
/// and one route on a map. Reached from the Journal's toolbar.
struct TripsScreen: View {
    @Query private var trips: [Trip]
    @State private var isCreating = false

    /// Most recent first; trips without dates last.
    private var ordered: [Trip] {
        trips.sorted { lhs, rhs in
            switch (lhs.start, rhs.start) {
            case let (left?, right?): left > right
            case (.some, nil): true
            case (nil, _): false
            }
        }
    }

    var body: some View {
        Group {
            if trips.isEmpty {
                emptyState
            } else {
                List(ordered) { trip in
                    NavigationLink {
                        TripPage(trip: trip)
                    } label: {
                        TripRow(trip: trip)
                    }
                    .accessibilityIdentifier("tripRow")
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Palette.background.color)
        .navigationTitle("Trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New trip", systemImage: "plus") {
                    isCreating = true
                }
                .accessibilityIdentifier("newTripButton")
            }
        }
        .sheet(isPresented: $isCreating) {
            TripEditor(trip: nil)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "airplane")
                .font(.largeTitle)
                .foregroundStyle(Palette.brand.color)
                .accessibilityHidden(true)
            Text("No trips yet")
                .typeToken(.voice)
                .foregroundStyle(Palette.textPrimary.color)
            Text("Group a flight, a few meals and some cafés into one trip, with its route on a map.")
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .multilineTextAlignment(.center)
            Button("Plan a trip") {
                isCreating = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand.color)
            .accessibilityIdentifier("planTripButton")
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One trip in the list: its name, its dates and how much it holds.
private struct TripRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(trip.name.isEmpty ? "Untitled trip" : trip.name)
                .typeToken(.headline)
                .foregroundStyle(Palette.textPrimary.color)
            Text(TripText.dates(start: trip.start, end: trip.end))
                .typeToken(.callout)
                .foregroundStyle(Palette.textSecondary.color)
            Text(TripText.count(trip.entries?.count ?? 0))
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The words trips use for dates and counts.
enum TripText {
    /// "1 – 5 Jun 2026", "1 Jun – 3 Jul 2026", "12 Mar 2026" for one day, "No dates" for none.
    static func dates(start: Date?, end: Date?, calendar: Calendar = .current) -> String {
        guard let start else { return "No dates" }
        guard let end, !calendar.isDate(start, inSameDayAs: end) else {
            return start.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return (start ..< end).formatted(.interval.day().month(.abbreviated).year())
    }

    /// "No entries yet", "1 entry", "5 entries".
    static func count(_ entries: Int) -> String {
        switch entries {
        case 0: "No entries yet"
        case 1: "1 entry"
        default: "\(entries) entries"
        }
    }
}
