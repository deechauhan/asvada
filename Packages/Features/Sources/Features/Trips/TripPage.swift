import CoreLocation
import DesignSystem
import Geo
import MapKit
import Model
import Storage
import SwiftData
import SwiftUI

/// One trip (#66): the route on a map, then its entries day by day. Edit changes the name, dates
/// and entries; Delete removes the trip and leaves the entries where they are.
struct TripPage: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isMakingPoster = false

    private var summary: TripSummary {
        TripSummary.make(entries: trip.entries ?? [])
    }

    private var repository: Repository {
        Repository(context: context)
    }

    var body: some View {
        // Deleted from here: nothing to show while the screen pops back.
        if trip.isDeleted || trip.modelContext == nil {
            Color.clear
        } else {
            page
        }
    }

    private var page: some View {
        let summary = summary
        return List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(TripText.dates(start: trip.start, end: trip.end))
                        .typeToken(.callout)
                        .foregroundStyle(Palette.textSecondary.color)
                        .accessibilityIdentifier("tripDates")
                    Text(TripText.count(summary.entryCount))
                        .typeToken(.caption)
                        .foregroundStyle(Palette.textSecondary.color)
                }
                if !summary.route.isEmpty {
                    TripRouteMap(route: summary.route)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        .listRowInsets(EdgeInsets())
                }
            }
            if summary.days.isEmpty {
                Section {
                    Text("No entries in this trip yet. Edit it to add what you savoured in these dates.")
                        .typeToken(.callout)
                        .foregroundStyle(Palette.textSecondary.color)
                }
            }
            ForEach(summary.days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        if let item = entry.item {
                            NavigationLink {
                                ItemDetailScreen(item: item)
                            } label: {
                                TripEntryRow(entry: entry, item: item)
                            }
                            .accessibilityIdentifier("tripEntry")
                        }
                    }
                } header: {
                    Text(day.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle(trip.name.isEmpty ? "Trip" : trip.name)
        .navigationBarTitleDisplayModeInline()
        .accessibilityIdentifier("tripPage")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Poster", systemImage: "photo.artframe") { isMakingPoster = true }
                    .accessibilityIdentifier("tripPosterButton")
                Button("Edit", systemImage: "pencil") { isEditing = true }
                    .accessibilityIdentifier("editTripButton")
                Button("Delete trip", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    .accessibilityIdentifier("deleteTripButton")
            }
        }
        .sheet(isPresented: $isEditing) {
            TripEditor(trip: trip)
        }
        .sheet(isPresented: $isMakingPoster) {
            PosterSheet(subject: PosterSubject(trip: trip))
        }
        .confirmationDialog("Delete this trip?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                try? repository.deleteTrip(trip)
                dismiss()
            }
            .accessibilityIdentifier("confirmDeleteTrip")
        } message: {
            Text("Its entries stay where they are.")
        }
    }
}

/// An entry on a trip's day: what it was, in its collection's colour, and when.
private struct TripEntryRow: View {
    let entry: Entry
    let item: Item

    var body: some View {
        HStack(spacing: Spacing.medium) {
            if let collection = item.collection {
                Image(systemName: collection.icon)
                    .foregroundStyle(collection.accent.token.color)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.name)
                    .typeToken(.body)
                    .foregroundStyle(Palette.textPrimary.color)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The trip's route: a plum line through its places in order, with a numbered pin at each.
private struct TripRouteMap: View {
    let route: [GeoPoint]

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Palette.brand.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
            }
            ForEach(Array(coordinates.enumerated()), id: \.offset) { index, coordinate in
                Annotation("Stop \(index + 1)", coordinate: coordinate, anchor: .center) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.onBrand.color)
                        .frame(width: 24, height: 24)
                        .background(Palette.brand.color, in: Circle())
                }
                .annotationTitles(.hidden)
            }
        }
        .accessibilityLabel("Route map, \(coordinates.count) stops")
        .accessibilityIdentifier("tripMap")
    }
}
