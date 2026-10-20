import Foundation
import PlayerzAPI

/// The web's words for coaches and lessons (#19, `coaches`).
enum CoachText {
    static func money(_ cents: Int, _ currency: String) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: currency))
    }

    static func name(_ name: String?) -> String {
        name ?? String(localized: "coaches.noName")
    }

    /// «4,6 ★ (12)»; nothing before a first review.
    static func rating(_ rating: Components.Schemas.CoachRating) -> String? {
        guard rating.reviewCount > 0 else { return nil }
        let shown = rating.avgRating.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "coaches.cardRating \(shown) \(rating.reviewCount)")
    }

    /// «Падел: нива 2–5», or one level.
    static func levels(_ sport: Components.Schemas.CoachSportLevels) -> String {
        let name = GameText.sport(sport.sport)
        return sport.levelMin == sport.levelMax
            ? String(localized: "coaches.page.sportOne \(name) \(sport.levelMin)")
            : String(localized: "coaches.page.sportRange \(name) \(sport.levelMin) \(sport.levelMax)")
    }

    /// A refusal of a lesson, in the web's words. `NO_SHOW_BLOCKED` and
    /// `PLAYER_ACCOUNT_REQUIRED` come written in the player's language.
    static func lessonError(_ code: String?, message: String?, totalCents: Int?, currency: String) -> String {
        switch code {
        case "COACH_TAKEN": String(localized: "coaches.lesson.sheet.error.coachTaken")
        case "SLOT_TAKEN": String(localized: "coaches.lesson.sheet.error.noCourt")
        case "LESSON_TIME_NOT_OFFERED", "SLOT_NOT_BOOKABLE": String(localized: "coaches.lesson.sheet.error.notOffered")
        case "LESSON_PRICE_CHANGED":
            totalCents.map { String(localized: "coaches.lesson.sheet.error.priceChanged \(money($0, currency))") }
                ?? String(localized: "coaches.lesson.sheet.error.priceChangedNoPrice")
        case "COACH_NOT_BOOKABLE", "LESSON_LENGTH_NOT_OFFERED": String(localized: "coaches.lesson.sheet.error.notBookable")
        case "OWN_LESSON": String(localized: "coaches.lesson.sheet.error.ownLesson")
        case "NO_SHOW_BLOCKED", "PLAYER_ACCOUNT_REQUIRED", "BOOKING_LIMIT_REACHED":
            message ?? String(localized: "coaches.lesson.sheet.error.failed")
        default: String(localized: "coaches.lesson.sheet.error.failed")
        }
    }
}
