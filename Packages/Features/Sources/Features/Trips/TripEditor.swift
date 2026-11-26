import DesignSystem
import Model
import Storage
import SwiftData
import SwiftUI

/// Creates a trip, or edits one (#66): a name, the dates, and which entries made in those dates
/// belong to it. Entries in the dates that no other trip has are suggested, all ticked.
struct TripEditor: View {
    /// The trip being edited; nil creates one.
    let trip: Trip?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var start: Date
    @State private var end: Date
    /// Entries left out of the trip, by id (everything suggested starts in).
    @State private var leftOut: Set<UUID> = []

    init(trip: Trip?) {
        self.trip = trip
        _name = State(initialValue: trip?.name ?? "")
        let first = trip?.start ?? Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
        _start = State(initialValue: first)
        _end = State(initialValue: trip?.end ?? .now)
    }

    private var repository: Repository {
        Repository(context: context)
    }

    private var suggestions: [Entry] {
        (try? repository.suggestedEntries(from: start, to: end, excluding: trip)) ?? []
    }

    private var chosen: [Entry] {
        suggestions.filter { !leftOut.contains($0.id) }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Lisbon in June", text: $name)
                        .accessibilityIdentifier("tripNameField")
                    DatePicker("From", selection: $start, displayedComponents: .date)
                        .accessibilityIdentifier("tripStart")
                    DatePicker("To", selection: $end, in: start..., displayedComponents: .date)
                        .accessibilityIdentifier("tripEnd")
                }
                Section {
                    if suggestions.isEmpty {
                        Text("Nothing savoured in these dates that isn't in another trip.")
                            .typeToken(.callout)
                            .foregroundStyle(Palette.textSecondary.color)
                    }
                    ForEach(suggestions) { entry in
                        entryToggle(entry)
                    }
                } header: {
                    Text("Entries in these dates")
                } footer: {
                    Text("Untick any that weren't part of the trip.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle(trip == nil ? "New trip" : "Edit trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                        .accessibilityIdentifier("saveTripButton")
                }
            }
        }
    }

    private func entryToggle(_ entry: Entry) -> some View {
        Toggle(isOn: Binding(
            get: { !leftOut.contains(entry.id) },
            set: { isIn in
                if isIn {
                    leftOut.remove(entry.id)
                } else {
                    leftOut.insert(entry.id)
                }
            },
        )) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.item?.name ?? "")
                    .typeToken(.body)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .typeToken(.caption)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .accessibilityIdentifier("tripEntryToggle")
    }

    private func save() {
        do {
            if let trip {
                try repository.update(trip, name: name, start: start, end: end, entries: chosen)
            } else {
                try repository.createTrip(name: name, start: start, end: end, entries: chosen)
            }
            dismiss()
        } catch {
            assertionFailure("Saving trip failed: \(error)")
        }
    }
}
