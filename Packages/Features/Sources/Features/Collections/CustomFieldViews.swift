import DesignSystem
import Model
import SwiftUI

/// A collection's custom fields in the entry form (#22): one control per field, by type. A value
/// is kept only while it has something in it: blank text, an unset date and a "No" switch are
/// as good as unanswered.
struct CustomFieldsForm: View {
    let fields: [CollectionField]
    @Binding var values: [UUID: FieldValue]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(fields) { field in
                row(for: field)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("customField-\(field.name)")
            }
        }
    }

    @ViewBuilder
    private func row(for field: CollectionField) -> some View {
        switch field.type {
        case .text:
            TextField(field.name, text: textBinding(field))
                .textFieldStyle(.roundedBorder)
        case .number:
            TextField(field.name, value: numberBinding(field), format: .number)
                .textFieldStyle(.roundedBorder)
                .decimalKeyboard()
        case .choice:
            Picker(field.name, selection: choiceBinding(field)) {
                Text("Not set").tag("")
                ForEach(field.choices, id: \.self) { Text($0).tag($0) }
            }
        case .date:
            dateRow(for: field)
        case .yesNo:
            Toggle(field.name, isOn: yesNoBinding(field))
        }
    }

    private func dateRow(for field: CollectionField) -> some View {
        HStack {
            if case let .date(date) = values[field.id] {
                DatePicker(field.name, selection: dateBinding(field, fallback: date), displayedComponents: .date)
                Button("Clear", systemImage: "xmark.circle.fill") {
                    values[field.id] = nil
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Clear \(field.name)")
            } else {
                Text(field.name)
                    .typeToken(.body)
                Spacer(minLength: 0)
                Button("Set date") {
                    values[field.id] = .date(.now)
                }
                .accessibilityLabel("Set \(field.name)")
            }
        }
    }

    // MARK: - Bindings

    private func textBinding(_ field: CollectionField) -> Binding<String> {
        Binding {
            if case let .text(text) = values[field.id] {
                return text
            }
            return ""
        } set: { text in
            values[field.id] = text.isEmpty ? nil : FieldValue.text(text)
        }
    }

    private func numberBinding(_ field: CollectionField) -> Binding<Double?> {
        Binding {
            if case let .number(number) = values[field.id] {
                return number
            }
            return nil
        } set: { number in
            values[field.id] = number.map(FieldValue.number)
        }
    }

    private func choiceBinding(_ field: CollectionField) -> Binding<String> {
        Binding {
            if case let .choice(choice) = values[field.id] {
                return choice
            }
            return ""
        } set: { choice in
            values[field.id] = choice.isEmpty ? nil : FieldValue.choice(choice)
        }
    }

    private func dateBinding(_ field: CollectionField, fallback: Date) -> Binding<Date> {
        Binding {
            if case let .date(date) = values[field.id] {
                return date
            }
            return fallback
        } set: { date in
            values[field.id] = .date(date)
        }
    }

    private func yesNoBinding(_ field: CollectionField) -> Binding<Bool> {
        Binding {
            if case let .yesNo(flag) = values[field.id] {
                return flag
            }
            return false
        } set: { flag in
            values[field.id] = flag ? FieldValue.yesNo(true) : nil
        }
    }
}

/// The collection editor's "Your fields" section: add, rename, retype and remove fields.
struct FieldsEditorSection: View {
    @Binding var fields: [CollectionField]

    var body: some View {
        Section {
            ForEach($fields) { $field in
                FieldEditorRow(field: $field) {
                    fields.removeAll { $0.id == field.id }
                }
            }
            if fields.count < CollectionField.maximumPerCollection {
                Button("Add a field", systemImage: "plus.circle") {
                    fields.append(CollectionField())
                }
                .accessibilityIdentifier("addFieldButton")
            }
        } header: {
            Text("Your fields")
        } footer: {
            Text("Extra things to record each time, like Seat or Dish ordered.")
        }
    }
}

private struct FieldEditorRow: View {
    @Binding var field: CollectionField
    let remove: () -> Void
    /// The choices as typed, kept as text so a trailing comma survives while typing.
    @State private var choicesText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                TextField("Field name, e.g. Seat", text: $field.name)
                    .accessibilityIdentifier("fieldNameField")
                Button("Remove field", systemImage: "minus.circle.fill", role: .destructive, action: remove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            Picker("Type", selection: $field.type) {
                ForEach(FieldType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            if field.type == .choice {
                TextField("Options, separated by commas", text: $choicesText)
                    .accessibilityIdentifier("fieldChoicesField")
                    .onChange(of: choicesText) { _, text in
                        field.choices = text.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    }
            }
        }
        .onAppear { choicesText = field.choices.joined(separator: ", ") }
    }
}

extension FieldType {
    /// How the type reads in the editor's picker.
    var displayName: String {
        switch self {
        case .text: "Text"
        case .number: "Number"
        case .choice: "One of a list"
        case .date: "Date"
        case .yesNo: "Yes or no"
        }
    }
}
