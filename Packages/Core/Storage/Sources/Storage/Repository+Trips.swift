import Foundation
import Geo
import Model
import SwiftData

/// One day of a trip: the day, and the entries made on it, earliest first.
public struct TripDay: Equatable, Identifiable {
    public let day: Date
    public let entries: [Entry]

    public var id: Date {
        day
    }

    public static func == (lhs: TripDay, rhs: TripDay) -> Bool {
        lhs.day == rhs.day && lhs.entries.map(\.id) == rhs.entries.map(\.id)
    }
}

/// A trip laid out for its page (#66): its entries by day, earliest day first, and the route
/// through the places they happened, in order.
public struct TripSummary: Equatable {
    public let days: [TripDay]
    /// Where each entry's place is, in date order, with a place repeated in a row counted once.
    public let route: [GeoPoint]

    public var entryCount: Int {
        days.reduce(0) { $0 + $1.entries.count }
    }

    /// Lays out `entries` (any order) by calendar day.
    public static func make(entries: [Entry], calendar: Calendar = .current) -> TripSummary {
        let sorted = entries.sorted { $0.date < $1.date }
        var days: [TripDay] = []
        var bucket: [Entry] = []
        var bucketDay: Date?
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.date)
            if day != bucketDay, let finished = bucketDay {
                days.append(TripDay(day: finished, entries: bucket))
                bucket = []
            }
            bucketDay = day
            bucket.append(entry)
        }
        if let bucketDay {
            days.append(TripDay(day: bucketDay, entries: bucket))
        }
        var route: [GeoPoint] = []
        for entry in sorted {
            guard let item = entry.item, let latitude = item.latitude, let longitude = item.longitude else { continue }
            let point = GeoPoint(longitude: longitude, latitude: latitude)
            if route.last != point {
                route.append(point)
            }
        }
        return TripSummary(days: days, route: route)
    }
}

public extension Repository {
    /// Every trip, the most recent first (trips without dates last).
    func trips() throws -> [Trip] {
        try context.fetch(FetchDescriptor<Trip>()).sorted { lhs, rhs in
            switch (lhs.start, rhs.start) {
            case let (left?, right?): left > right
            case (.some, nil): true
            case (nil, _): false
            }
        }
    }

    /// The entries made between `start` and `end` (whole days, both included) that no trip has
    /// yet, earliest first: what to suggest when a trip is created. `excluding` is a trip being
    /// edited, whose own entries are still offered.
    func suggestedEntries(
        from start: Date,
        to end: Date,
        excluding trip: Trip? = nil,
        calendar: Calendar = .current,
    ) throws -> [Entry] {
        let first = calendar.startOfDay(for: start)
        guard let after = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else { return [] }
        return try context.fetch(FetchDescriptor<Entry>())
            .filter { entry in
                entry.date >= first && entry.date < after
                    && entry.item != nil
                    && (entry.trip == nil || entry.trip?.id == trip?.id)
            }
            .sorted { $0.date < $1.date }
    }

    /// Creates a trip with the given entries. The end is never before the start.
    @discardableResult
    func createTrip(name: String, start: Date, end: Date, entries: [Entry]) throws -> Trip {
        let trip = Trip(name: name.trimmingCharacters(in: .whitespacesAndNewlines), start: start, end: max(start, end))
        context.insert(trip)
        for entry in entries {
            entry.trip = trip
        }
        try context.save()
        return trip
    }

    /// Changes a trip's name and dates and which entries belong to it: those in `entries` are in,
    /// every other entry is taken out.
    func update(_ trip: Trip, name: String, start: Date, end: Date, entries: [Entry]) throws {
        trip.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.start = start
        trip.end = max(start, end)
        let keep = Set(entries.map(\.id))
        for entry in trip.entries ?? [] where !keep.contains(entry.id) {
            entry.trip = nil
        }
        for entry in entries {
            entry.trip = trip
        }
        try context.save()
    }

    /// Deletes a trip. Its entries stay where they are, just no longer grouped.
    func deleteTrip(_ trip: Trip) throws {
        for entry in trip.entries ?? [] {
            entry.trip = nil
        }
        context.delete(trip)
        try context.save()
    }
}
