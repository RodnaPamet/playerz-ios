import Foundation
import Testing

@testable import PlayerzAPI

@Suite("The days a lesson can be booked on")
struct LessonDaysTests {
    private func instant(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    @Test("today at the venue and the next 13 days")
    func fourteenDays() throws {
        let days = LessonDays.days(from: try instant("2026-10-20T09:00:00Z"), timezone: "Europe/Sofia")
        #expect(days.count == 14)
        #expect(days.first == "2026-10-20")
        #expect(days.last == "2026-11-02")
    }

    @Test("the venue's day, not the phone's")
    func venueCalendar() throws {
        // 22:30 UTC is already 01:30 the next day in Sofia (EEST, UTC+3).
        let late = try instant("2026-10-20T22:30:00Z")
        #expect(LessonDays.days(from: late, timezone: "Europe/Sofia").first == "2026-10-21")
        #expect(LessonDays.days(from: late, timezone: "America/New_York").first == "2026-10-20")
    }

    @Test("the clocks going back keep one entry a day")
    func dstEnd() throws {
        // Bulgaria leaves summer time on 25 October 2026.
        let days = LessonDays.days(from: try instant("2026-10-24T12:00:00Z"), timezone: "Europe/Sofia")
        #expect(days.prefix(3) == ["2026-10-24", "2026-10-25", "2026-10-26"])
        #expect(Set(days).count == days.count)
    }
}
