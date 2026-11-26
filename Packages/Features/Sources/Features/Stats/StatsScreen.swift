import Charts
import DesignSystem
import Model
import SwiftData
import SwiftUI

/// Look back (#68): stats for everything (what you've savoured, how much of the world, the last
/// twelve months) and for each drawer (its standout, and for ranked drawers the best in each
/// country). Reached from the Collections toolbar.
struct StatsScreen: View {
    @Query(sort: [SortDescriptor(\ExperienceCollection.sortIndex), SortDescriptor(\ExperienceCollection.name)])
    private var collections: [ExperienceCollection]

    var body: some View {
        let stats = LookBackStats(collections: collections)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                tiles(stats)
                MonthsChart(months: stats.months)
                ForEach(stats.drawers.filter { $0.items > 0 }) { drawer in
                    DrawerStatsCard(stats: drawer)
                }
                if stats.items == 0 {
                    Text("Nothing savoured yet. Your stats fill in as you seal keepsakes.")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Palette.textSecondary.color)
                }
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .navigationTitle("Look back")
        .accessibilityIdentifier("statsScreen")
    }

    /// The headline numbers as serif stat tiles (never a bare 0: an empty tile says so).
    private func tiles(_ stats: LookBackStats) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            StatTile(
                value: stats.entries > 0 ? stats.entries.formatted() : nil,
                caption: stats.entries == 1 ? "thing savoured" : "things savoured",
                empty: "Nothing yet",
            )
            StatTile(
                value: stats.countries > 0 ? stats.countries.formatted() : nil,
                caption: "countries · \(stats.worldShare.formatted(.percent.precision(.fractionLength(0))))",
                empty: "No stamps yet",
                progress: stats.worldShare,
            )
            if let favourite = stats.favourite {
                StatTile(value: "×\(favourite.count)", caption: favourite.name, empty: "")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One headline number: serif numerals with a saffron macron, and what it counts.
private struct StatTile: View {
    let value: String?
    let caption: String
    let empty: String
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let value {
                Text(value)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.brand.color)
                MacronBar(progress: progress ?? 1, height: 3)
                    .frame(width: 44)
                Text(caption)
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
                    .lineLimit(2)
            } else {
                Text(empty)
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .combine)
    }
}

/// Entries per month for the last twelve months: one plum bar a month, thin with rounded tops,
/// on recessive axes. VoiceOver hears a summary, then each month's count.
private struct MonthsChart: View {
    let months: [MonthCount]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("The last twelve months")
                .typeToken(.headline)
                .foregroundStyle(Palette.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Chart(months) { month in
                BarMark(
                    x: .value("Month", month.start, unit: .month),
                    y: .value("Savoured", month.count),
                    width: .ratio(0.55),
                )
                .foregroundStyle(Palette.brand.color)
                .cornerRadius(4)
                .accessibilityLabel(month.start.formatted(.dateTime.month(.wide).year()))
                .accessibilityValue(month.count == 1 ? "1 thing" : "\(month.count) things")
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Palette.textSecondary.color)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Palette.separator.color)
                    AxisValueLabel().foregroundStyle(Palette.textSecondary.color)
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Things savoured each month")
            .accessibilityValue(LookBackStats.chartSummary(months))
            .accessibilityIdentifier("monthsChart")
        }
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

/// One drawer's stats: its name, how much it holds, its standout, and (ranked) the best in each
/// country.
private struct DrawerStatsCard: View {
    let stats: CollectionStats

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label(stats.collection.name, systemImage: stats.collection.icon)
                .typeToken(.headline)
                .foregroundStyle(stats.collection.accent.token.color)
                .accessibilityAddTraits(.isHeader)
            Text(StatsText.holds(items: stats.items, entries: stats.entries))
                .typeToken(.caption)
                .foregroundStyle(Palette.textSecondary.color)
            if let standout = stats.standout {
                Text(standout)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Palette.textPrimary.color)
            }
            if !stats.leadersByCountry.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Best in each country")
                        .typeToken(.ticketLabel)
                        .foregroundStyle(Palette.textSecondary.color)
                    ForEach(stats.leadersByCountry) { leader in
                        HStack {
                            Text(leader.countryName)
                                .typeToken(.callout)
                                .foregroundStyle(Palette.textSecondary.color)
                            Spacer(minLength: Spacing.small)
                            Text(leader.itemName)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(Palette.textPrimary.color)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.medium))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drawerStats")
    }
}

/// The words the stats use.
enum StatsText {
    /// "4 things · 6 entries", "1 thing · 1 entry".
    static func holds(items: Int, entries: Int) -> String {
        let things = items == 1 ? "1 thing" : "\(items) things"
        let times = entries == 1 ? "1 entry" : "\(entries) entries"
        return "\(things) · \(times)"
    }
}
