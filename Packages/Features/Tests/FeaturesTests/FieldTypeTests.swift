import Model
import Testing
@testable import Features

struct FieldTypeTests {
    @Test func everyTypeHasAReadableName() {
        let names = FieldType.allCases.map(\.displayName)
        #expect(names == ["Text", "Number", "One of a list", "Date", "Yes or no"])
        #expect(Set(names).count == FieldType.allCases.count)
    }
}
