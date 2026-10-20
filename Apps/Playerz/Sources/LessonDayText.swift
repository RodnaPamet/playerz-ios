import Foundation

/// A lesson's day and time, on the venue's calendar and clock (#19).
enum LessonDayText {
    /// «пн, 21 окт.» for `2026-10-21`.
    static func label(_ day: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return day }
        return date.formatted(
            Date.FormatStyle(timeZone: calendar.timeZone).weekday(.abbreviated).day().month(.abbreviated)
        )
    }

    /// «19:00», at the venue.
    static func time(_ date: Date, timezone: String) -> String {
        date.formatted(
            Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
                .hour(.twoDigits(amPM: .omitted)).minute()
        )
    }
}
