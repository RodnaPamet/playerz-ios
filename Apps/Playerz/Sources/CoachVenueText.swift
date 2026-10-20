import Foundation
import PlayerzAPI

/// The web's words for a coach's venues, terms and days off (#21, `coachVenues`).
enum CoachVenueText {
    static func status(_ status: Components.Schemas.MyCoachLink.statusPayload) -> String {
        localized(key: "coachVenues.status.\(status.rawValue)")
    }

    /// «Monday», on the venue's week: 0 = Sunday … 6 = Saturday.
    static func day(_ dayOfWeek: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        let names = calendar.standaloneWeekdaySymbols
        return names.indices.contains(dayOfWeek) ? names[dayOfWeek].localizedCapitalized : String(dayOfWeek)
    }

    static func error(_ error: Components.Schemas._Error.errorPayload) -> String {
        let codes = [
            "COACH_NOT_APPROVED", "COACH_LINK_EXISTS", "COACH_LINK_STATE", "COACH_LINK_NOT_FOUND",
            "COACH_SUSPENDED_AT_CLUB", "VENUE_NOT_FOUND", "COACH_TIME_OFF_LIMIT", "RATE_LIMITED",
        ]
        if codes.contains(error.code) { return localized(key: "coachVenues.error.\(error.code)") }
        // A field the server refused names itself, as the web reads it.
        let fields = ["hourlyRateCents", "groupRateCents", "lessonMinutes", "cancelCutoffHours", "hours", "startDate", "endDate", "note"]
        if let field = error.details?.additionalProperties.value["field"] as? String, fields.contains(field) {
            return localized(key: "coachVenues.error.\(field)")
        }
        return String(localized: "coachVenues.error.UNKNOWN")
    }
}
