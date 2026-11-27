import DesignSystem
import Foundation
import Model

/// The lucky dip (INTERACTION.md §7, #159): spin the cabinet and it hands you a keepsake you'd
/// forgotten. This is the picking and the spin's arithmetic; the cabinet does the turning.
enum LuckyDip {
    /// A release faster than this (points per second) spins the cabinet instead of rolling it.
    static let flingSpeed = 2300.0
    /// Full turns of the ring before it lands.
    static let revolutions = 2
    /// Not savoured for this long counts as forgotten.
    static let forgottenAfter: TimeInterval = 90 * 86400

    /// How much more likely `item` is to come up: twice for an anniversary today, twice if it
    /// hasn't been savoured for 90 days, twice if it has a note or a photo (so up to ×8).
    static func weight(of item: Item, now: Date, calendar: Calendar = .current) -> Double {
        let entries = item.entries ?? []
        var weight = 1.0
        if !OnThisDay.anniversaries(in: entries, on: now, calendar: calendar).isEmpty {
            weight *= 2
        }
        if now.timeIntervalSince(item.lastEncountered) >= forgottenAfter {
            weight *= 2
        }
        if entries.contains(where: { !$0.notes.isEmpty || !($0.photos ?? []).isEmpty }) {
            weight *= 2
        }
        return weight
    }

    /// A keepsake from the drawers' items, by weight: never one whose drawer is empty (there's
    /// nothing to hand you), never `last` again unless it's the only one.
    static func pick(
        from collections: [ExperienceCollection],
        last: UUID?,
        now: Date = .now,
        calendar: Calendar = .current,
        using generator: inout some RandomNumberGenerator,
    ) -> Item? {
        let all = collections.flatMap { $0.items ?? [] }.filter { $0.collection != nil }
        let candidates = all.count > 1 ? all.filter { $0.id != last } : all
        let weights = candidates.map { weight(of: $0, now: now, calendar: calendar) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0 ..< total, using: &generator)
        for (item, weight) in zip(candidates, weights) {
            if roll < weight {
                return item
            }
            roll -= weight
        }
        return candidates.last
    }

    /// Where the ring stops to bring `index` to the front after `revolutions` full turns, always
    /// turning forward (to higher positions) from `position`, on a ring of `count` faces.
    static func spinTarget(from position: Double, to index: Int, count: Int, revolutions: Int = LuckyDip.revolutions) -> Double {
        guard count > 0 else { return position }
        let start = position.rounded()
        let front = CabinetDrum.wrap(Int(start), count: count)
        let ahead = CabinetDrum.wrap(index - front, count: count)
        return start + Double(revolutions * count + ahead)
    }

    /// When each of `steps` detents clicks during a spin of `duration` seconds: when the ease
    /// `1 − (1 − u)^3.2` passes each drawer, so the clicks slow down like a prize wheel.
    static func detentTimes(steps: Int, duration: Double) -> [Double] {
        guard steps > 0, duration > 0 else { return [] }
        return (1 ... steps).map { step in
            let progress = Double(step) / Double(steps)
            let time = 1 - pow(1 - progress, 1 / 3.2)
            return time * duration
        }
    }

    /// What VoiceOver says when it lands: "From your Cities drawer: Lisbon, savoured 14 September 2024".
    static func announcement(for item: Item) -> String {
        let drawer = item.collection?.name ?? "your"
        guard let latest = item.latestEntry else { return "From your \(drawer) drawer: \(item.name)" }
        return "From your \(drawer) drawer: \(item.name), savoured \(latest.date.formatted(date: .long, time: .omitted))"
    }
}
