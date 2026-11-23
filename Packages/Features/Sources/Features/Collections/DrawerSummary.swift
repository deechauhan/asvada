import Foundation
import Model

/// What a cabinet drawer says about its collection: a serif numeral and a short caption that
/// depend on the rating mode. An empty collection never shows "0": it says "Nothing savoured yet".
struct DrawerSummary: Equatable {
    /// The big serif numeral, or `nil` for an empty drawer.
    let numeral: String?
    /// The line beside the numeral, e.g. "No. 1 Prufrock" or "stamped · 2%".
    let caption: String
    /// The whole stat as VoiceOver should say it.
    let spoken: String

    static let emptyCaption = "Nothing savoured yet"

    /// Countries a checklist is measured against (UN members plus the two observer states).
    static let worldCountries = 195

    /// - Parameters:
    ///   - mode: the collection's rating mode.
    ///   - itemCount: how many items the collection holds.
    ///   - entryCount: how many entries those items have in total.
    ///   - leader: the top-ranked item's name (ranked mode).
    ///   - knownTotal: size of the known set for checklists (e.g. 195 countries), if any.
    static func make(
        mode: RatingMode,
        itemCount: Int,
        entryCount: Int,
        leader: String? = nil,
        knownTotal: Int? = nil,
    ) -> DrawerSummary {
        guard itemCount > 0 else {
            return DrawerSummary(numeral: nil, caption: emptyCaption, spoken: emptyCaption)
        }
        switch mode {
        case .checklist:
            guard let knownTotal, knownTotal > 0 else {
                return DrawerSummary(numeral: "\(itemCount)", caption: "stamped", spoken: "\(itemCount) stamped")
            }
            // Never round a real visit down to 0%.
            let percent = max(1, Int((Double(itemCount) / Double(knownTotal) * 100).rounded()))
            return DrawerSummary(
                numeral: "\(itemCount)",
                caption: "stamped · \(percent)%",
                spoken: "\(itemCount) stamped, \(percent) percent of \(knownTotal)",
            )
        case .ranked:
            guard let leader else {
                return DrawerSummary(numeral: "\(itemCount)", caption: "ranked", spoken: "\(itemCount) ranked")
            }
            return DrawerSummary(
                numeral: "\(itemCount)",
                caption: "No. 1 \(leader)",
                spoken: "\(itemCount) ranked, number one \(leader)",
            )
        case .log:
            let count = max(entryCount, itemCount)
            return DrawerSummary(numeral: "\(count)", caption: "logged", spoken: "\(count) logged")
        case .stars:
            return DrawerSummary(numeral: "\(itemCount)", caption: "savoured", spoken: "\(itemCount) savoured")
        }
    }
}

extension ExperienceCollection {
    /// The items a drawer fans out, best first: by rank for ranked collections, otherwise by the
    /// most recent encounter.
    func drawerItems(limit: Int = 3) -> [Item] {
        Array(Self.drawerOrder(items ?? [], mode: ratingMode).prefix(limit))
    }

    static func drawerOrder(_ items: [Item], mode: RatingMode) -> [Item] {
        items.sorted { lhs, rhs in
            if mode == .ranked, lhs.rankScore != rhs.rankScore {
                return (lhs.rankScore ?? -.infinity) > (rhs.rankScore ?? -.infinity)
            }
            let lhsDate = lhs.lastEncountered
            let rhsDate = rhs.lastEncountered
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// This collection's drawer stat.
    var drawerSummary: DrawerSummary {
        let items = items ?? []
        return DrawerSummary.make(
            mode: ratingMode,
            itemCount: items.count,
            entryCount: items.reduce(0) { $0 + ($1.entries?.count ?? 0) },
            leader: ratingMode == .ranked ? drawerItems(limit: 1).first?.name : nil,
            knownTotal: kind == .countries ? DrawerSummary.worldCountries : nil,
        )
    }
}

extension Item {
    /// The latest entry's date, or when the item was added.
    var lastEncountered: Date {
        entries?.map(\.date).max() ?? createdAt
    }

    /// First entry's date (a passport stamp's "entry" date).
    var firstEncountered: Date? {
        entries?.map(\.date).min()
    }

    /// The ISO code for a country item, from `countryCode` or an `iso:XX` external ref.
    var isoCode: String {
        if let countryCode, !countryCode.isEmpty {
            return countryCode
        }
        if let externalRef, externalRef.hasPrefix("iso:") {
            return String(externalRef.dropFirst(4))
        }
        return String(name.prefix(2)).uppercased()
    }
}
