import Foundation
import PlayerzAPI

/// The web's words for a coach's lessons (#21, `coachLessons`).
enum CoachLessonText {
    /// A refused cancel or no-show, as the web's `lessonErrorKey`.
    static func error(_ error: Components.Schemas._Error.errorPayload?) -> String {
        switch error?.code {
        case "LESSON_STARTED": return String(localized: "coachLessons.error.started")
        case "LESSON_NOT_FOUND": return String(localized: "coachLessons.error.gone")
        case "BOOKING_NOT_CANCELLABLE": return String(localized: "coachLessons.error.notAttendable")
        case "NO_SHOW_REFUSED":
            switch error?.details?.additionalProperties.value["reason"] as? String {
            case "NOT_STARTED": return String(localized: "coachLessons.error.notStarted")
            case "ALREADY_NO_SHOW": return String(localized: "coachLessons.error.alreadyNoShow")
            case "REVIEWED": return String(localized: "coachLessons.error.reviewed")
            default: return String(localized: "coachLessons.error.notAttendable")
            }
        default: return String(localized: "coachLessons.error.failed")
        }
    }
}
