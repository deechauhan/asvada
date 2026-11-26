import Foundation

/// What kind of answer a custom field takes (#22).
public enum FieldType: String, Codable, CaseIterable, Sendable {
    case text
    case number
    /// One of a fixed list of choices.
    case choice
    case date
    case yesNo
}

/// A field a collection adds to its entries: "Seat", "Dish ordered", "Cabin class". The fields of
/// a collection are stored as JSON in `ExperienceCollection.fieldSchemaJSON`, in the order they
/// appear in the entry form.
public struct CollectionField: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var type: FieldType
    /// The options of a `choice` field; empty for every other type.
    public var choices: [String]

    public init(id: UUID = UUID(), name: String = "", type: FieldType = .text, choices: [String] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.choices = choices
    }

    /// The most fields one collection may have.
    public static let maximumPerCollection = 12

    /// The fields worth keeping from what was edited: names trimmed, blanks dropped, choices
    /// trimmed and de-duplicated (and only kept on choice fields), a choice field with no choices
    /// turned into a text field, and no more than `maximumPerCollection`.
    public static func cleaned(_ fields: [CollectionField]) -> [CollectionField] {
        var result: [CollectionField] = []
        for field in fields {
            let name = field.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, result.count < maximumPerCollection else { continue }
            var kept = field
            kept.name = name
            var seen = Set<String>()
            kept.choices = field.type == .choice
                ? field.choices
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                : []
            if kept.type == .choice, kept.choices.isEmpty {
                kept.type = .text
            }
            result.append(kept)
        }
        return result
    }
}

/// What was entered for a field on one entry. Stored by field id in `Entry.extraJSON`.
public enum FieldValue: Codable, Equatable, Sendable {
    case text(String)
    case number(Double)
    case choice(String)
    case date(Date)
    case yesNo(Bool)

    /// How the value reads in a list or to VoiceOver: "F12", "3", "Business", "12 Mar 2026", "Yes".
    public var displayText: String {
        switch self {
        case let .text(text), let .choice(text): text
        case let .number(number): number.formatted(.number.precision(.fractionLength(0 ... 4)))
        case let .date(date): date.formatted(date: .abbreviated, time: .omitted)
        case let .yesNo(flag): flag ? "Yes" : "No"
        }
    }

    /// Whether there's anything to keep: blank text is as good as nothing.
    public var isEmpty: Bool {
        if case let .text(text) = self {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
}

public extension ExperienceCollection {
    /// The collection's custom fields, in form order. Setting them stores JSON (none stores nothing).
    var fields: [CollectionField] {
        get {
            guard let fieldSchemaJSON,
                  let decoded = try? JSONDecoder().decode([CollectionField].self, from: fieldSchemaJSON)
            else { return [] }
            return decoded
        }
        set {
            fieldSchemaJSON = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }
}

public extension Entry {
    /// What was entered in the collection's custom fields, by field id. Values for fields that
    /// have since been removed stay in the JSON, harmlessly, until the entry is next saved.
    var extraValues: [UUID: FieldValue] {
        get {
            guard let extraJSON,
                  let decoded = try? JSONDecoder().decode([String: FieldValue].self, from: extraJSON)
            else { return [:] }
            return Dictionary(
                decoded.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } },
                uniquingKeysWith: { first, _ in first },
            )
        }
        set {
            let kept = newValue.filter { !$0.value.isEmpty }
            extraJSON = kept.isEmpty
                ? nil
                : try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: kept.map { ($0.key.uuidString, $0.value) }))
        }
    }
}
