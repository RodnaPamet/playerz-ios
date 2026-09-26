import Foundation

/// A bookable day, named in the VENUE's timezone.
///
/// ═══ WHY THE VENUE'S ZONE AND NOT THE DEVICE'S ═══
///
/// The availability endpoint takes `date` as `YYYY-MM-DD` and says, in as many
/// words, that it is "interpreted in the VENUE's timezone (not UTC, and not the
/// device's zone)".
///
/// Format that string with the device's calendar and the request asks for the
/// wrong day for anybody not standing in Bulgaria — and, worse, for everybody
/// during the hours when the two zones disagree about the date. Someone in
/// London at 23:30 looking at a Sofia club would be shown tomorrow's slots
/// labelled as today, book one, and arrive a day late.
///
/// So the whole strip — what "today" means, which days follow it, and how each
/// is labelled — is computed in the venue's zone.
public struct VenueDay: Identifiable, Hashable, Sendable {
    /// `YYYY-MM-DD` as the API wants it.
    public let apiDate: String
    /// Midnight at the start of this day, in the venue's zone.
    public let start: Date
    public let isToday: Bool

    public var id: String { apiDate }

    /// The next `count` days starting from "today" AT THE VENUE.
    ///
    /// `days` on the endpoint is capped at 1..14, so a strip longer than that
    /// could offer a day the API will refuse.
    /// `fallback` is a parameter so the fallback itself can be tested.
    ///
    /// It defaulted to a hardcoded "Europe/Sofia", and a test comparing an
    /// unknown zone against Sofia passed whether the code fell back to Sofia or
    /// to `TimeZone.current` — because the machine it runs on IS Sofia. The
    /// test documented that trap and then walked into it. Injecting the zone is
    /// what makes the assertion mean something anywhere.
    public static func upcoming(
        inTimeZone identifier: String,
        count: Int = 14,
        now: Date = Date(),
        fallback: String = "Europe/Sofia"
    ) -> [VenueDay] {
        // An unknown identifier must not silently become the DEVICE's zone —
        // that is the bug this type exists to prevent. Sofia is the product's
        // home and the schema's own default for `VenueOrg.timezone`.
        let zone = TimeZone(identifier: identifier)
            ?? TimeZone(identifier: fallback)
            ?? .gmt

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = zone
        // Fixed locale: a Persian or Buddhist device calendar would otherwise
        // format a year the server cannot parse.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: now)

        return (0..<max(1, min(count, 14))).compactMap { offset in
            // `byAdding: .day` rather than adding 86 400 seconds: a DST day is
            // 23 or 25 hours long, and seconds-arithmetic skips or repeats a
            // date twice a year.
            guard let start = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return VenueDay(apiDate: formatter.string(from: start), start: start, isToday: offset == 0)
        }
    }

    /// A short label, in the venue's zone and the user's language.
    /// `today` is passed in because the string catalogue lives in the app
    /// target; a package cannot resolve the app's localisations.
    public func label(timeZone identifier: String, today: String) -> String {
        if isToday { return today }
        // `.timeZone(_:)` on FormatStyle takes a Symbol, not a TimeZone — the
        // zone belongs on the style's own property.
        var style = Date.FormatStyle(date: .abbreviated)
        style.timeZone = TimeZone(identifier: identifier) ?? style.timeZone
        return start.formatted(style)
    }
}
