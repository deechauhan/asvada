import Foundation
import Testing
@testable import Model

struct CollectionFieldTests {
    @Test func cleaningTrimsDropsBlanksAndFixesChoices() {
        let fields = [
            CollectionField(name: "  Seat ", type: .text),
            CollectionField(name: "   ", type: .number),
            CollectionField(name: "Cabin", type: .choice, choices: [" Economy ", "", "Business", "economy"]),
            CollectionField(name: "Notes", type: .choice, choices: []),
            CollectionField(name: "Rows", type: .number, choices: ["stray"]),
        ]
        let cleaned = CollectionField.cleaned(fields)
        #expect(cleaned.map(\.name) == ["Seat", "Cabin", "Notes", "Rows"])
        #expect(cleaned[1].choices == ["Economy", "Business"])
        // A choice field with nothing to choose is a text field.
        #expect(cleaned[2].type == .text)
        // Choices only belong to choice fields.
        #expect(cleaned[3].choices.isEmpty)
    }

    @Test func aCollectionHoldsNoMoreThanTheLimit() {
        let many = (1 ... 20).map { CollectionField(name: "Field \($0)") }
        #expect(CollectionField.cleaned(many).count == CollectionField.maximumPerCollection)
    }

    @Test func fieldValuesReadAsText() {
        #expect(FieldValue.text("F12").displayText == "F12")
        #expect(FieldValue.number(3).displayText == "3")
        #expect(FieldValue.number(2.5).displayText == "2.5")
        #expect(FieldValue.choice("Business").displayText == "Business")
        #expect(FieldValue.yesNo(true).displayText == "Yes")
        #expect(FieldValue.yesNo(false).displayText == "No")
        #expect(!FieldValue.date(Date(timeIntervalSince1970: 0)).displayText.isEmpty)
    }

    @Test func blankTextIsEmptyButNoAnswerIsNot() {
        #expect(FieldValue.text("  ").isEmpty)
        #expect(!FieldValue.text("x").isEmpty)
        #expect(!FieldValue.yesNo(false).isEmpty)
        #expect(!FieldValue.number(0).isEmpty)
    }

    @Test func fieldsRoundTripThroughACollection() {
        let collection = ExperienceCollection(name: "Flights")
        #expect(collection.fields.isEmpty)
        #expect(collection.fieldSchemaJSON == nil)
        let seat = CollectionField(name: "Seat")
        let cabin = CollectionField(name: "Cabin", type: .choice, choices: ["Economy", "Business"])
        collection.fields = [seat, cabin]
        #expect(collection.fields == [seat, cabin])
        collection.fields = []
        #expect(collection.fieldSchemaJSON == nil)
    }

    @Test func valuesRoundTripThroughAnEntryByFieldId() {
        let entry = Entry()
        let seat = UUID()
        let when = UUID()
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000.5)
        entry.extraValues = [seat: .text("F12"), when: .date(date), UUID(): .text("  ")]
        // The blank answer isn't kept.
        #expect(entry.extraValues.count == 2)
        #expect(entry.extraValues[seat] == .text("F12"))
        #expect(entry.extraValues[when] == .date(date))
        entry.extraValues = [:]
        #expect(entry.extraJSON == nil)
    }

    @Test func aDamagedValueBlobReadsAsNothing() {
        let entry = Entry()
        entry.extraJSON = Data("not json".utf8)
        #expect(entry.extraValues.isEmpty)
        let collection = ExperienceCollection(name: "X")
        collection.fieldSchemaJSON = Data("[1, 2".utf8)
        #expect(collection.fields.isEmpty)
    }
}
