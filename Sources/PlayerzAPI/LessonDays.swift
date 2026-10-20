import Foundation

/// The days a lesson can be booked on (playerz-ios#19), as the web's coach
/// page offers them: today at the venue and the next 13 days, `YYYY-MM-DD`
/// on the VENUE's calendar. Late in the evening in Sofia it is already
/// tomorrow there for a phone on another clock, and the server reads the day
/// as the venue's.
public enum LessonDays {
    public static let count = 14

    public static func days(from now: Date, timezone: String) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        let today = calendar.startOfDay(for: now)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map { day in
                let parts = calendar.dateComponents([.year, .month, .day], from: day)
                return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            }
        }
    }
}
