import DesignSystem
import Geo
import Model
import Storage
import SwiftData
import SwiftUI

/// The Countries drawer's checklist (#38): how much of the world is stamped ("23 · 12%" with a
/// ring), a MacronBar per continent, and the stamp pad to stamp or wash off countries. Every stamp
/// is saved as it lands. The passport spread itself is #44.
struct PassportPanel: View {
    let collection: ExperienceCollection
    @Environment(\.modelContext) private var context
    @State private var stamped: Set<String> = []
    /// Set once the stored stamps are loaded, so loading them isn't saved back as a change.
    @State private var loaded = false

    private var progress: ChecklistProgress {
        ChecklistProgress(stamped: stamped)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            header
            continents
            StampPad(stamped: $stamped, showsCounter: false)
        }
        .onAppear(perform: load)
        .onChange(of: stamped) { _, codes in
            guard loaded else { return }
            try? Repository(context: context).setStamped(codes, in: collection)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.medium) {
            ProgressRing(progress: progress.fraction, lineWidth: 5)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(progress.headline)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary.color)
                    .contentTransition(.numericText())
                Text("of \(progress.total) countries")
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.spoken)
        .accessibilityIdentifier("passportProgress")
    }

    private var continents: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ForEach(progress.continents) { part in
                HStack(spacing: Spacing.medium) {
                    Text(part.continent.name)
                        .typeToken(.callout)
                        .foregroundStyle(Palette.textPrimary.color)
                        .frame(width: 112, alignment: .leading)
                    MacronBar(progress: part.fraction)
                    Text("\(part.stamped)/\(part.total)")
                        .font(.system(.callout, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary.color)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(part.spoken)
                .accessibilityIdentifier("continentProgress-\(part.continent.name)")
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        stamped = Repository(context: context).stampedCodes(in: collection)
        // Mark loaded after the stored stamps land, so loading isn't saved as an edit.
        Task { @MainActor in loaded = true }
    }
}
