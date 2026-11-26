import Foundation
import Testing
@testable import Features

struct TripTextTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    @Test func countsReadInWords() {
        #expect(TripText.count(0) == "No entries yet")
        #expect(TripText.count(1) == "1 entry")
        #expect(TripText.count(5) == "5 entries")
    }

    @Test func noDatesSaysSo() {
        #expect(TripText.dates(start: nil, end: nil) == "No dates")
    }

    @Test func aSingleDayShowsOneDate() {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let text = TripText.dates(start: day, end: day, calendar: utc)
        #expect(text == day.formatted(.dateTime.day().month(.abbreviated).year()))
        #expect(!text.contains("–"))
    }

    @Test func aRangeShowsBothEnds() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(4 * 86400)
        let text = TripText.dates(start: start, end: end, calendar: utc)
        #expect(text.contains("–") || text.contains("-"))
    }
}
