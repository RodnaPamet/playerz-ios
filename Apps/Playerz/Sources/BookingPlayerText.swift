import Foundation

/// The web's words for the players on a booking (`myBookings.players`).
enum BookingPlayerText {
    /// A refusal of adding, removing, leaving or a new invite link.
    static func error(_ code: String?) -> String {
        switch code {
        case "BOOKING_FULL": String(localized: "myBookings.players.error.FULL")
        case "BOOKING_PLAYERS_CLOSED": String(localized: "myBookings.players.error.CLOSED")
        case "TOO_MANY_INVITE_LINKS": String(localized: "myBookings.players.error.TOO_MANY")
        default: String(localized: "myBookings.players.error.FAILED")
        }
    }

    /// A refusal of a venue review.
    static func reviewError(_ code: String?) -> String {
        switch code {
        case "INVALID_RATING": String(localized: "myBookings.review.error.RATING_REQUIRED")
        case "NO_PROOF_OF_VISIT": String(localized: "myBookings.review.error.NO_PROOF_OF_VISIT")
        case "ALREADY_REVIEWED": String(localized: "myBookings.review.error.ALREADY_REVIEWED")
        case "FORBIDDEN": String(localized: "myBookings.review.error.NOT_ALLOWED")
        default: String(localized: "myBookings.review.error.FAILED")
        }
    }

    /// A refusal of joining through an invite link, as the web's
    /// `joinErrorKey`; `RATE_LIMITED` stands for a 429, which has no code.
    static func joinError(_ code: String?) -> String {
        switch code {
        case "BOOKING_FULL": String(localized: "bookingInvite.error.FULL")
        case "BOOKING_INVITE_NOT_USABLE": String(localized: "bookingInvite.error.NOT_USABLE")
        case "PLAYER_ACCOUNT_REQUIRED": String(localized: "bookingInvite.error.PLAYER_ACCOUNT_REQUIRED")
        case "PHONE_REQUIRED": String(localized: "bookingInvite.error.PHONE_REQUIRED")
        case "RATE_LIMITED": String(localized: "bookingInvite.error.RATE_LIMITED")
        default: String(localized: "bookingInvite.error.FAILED")
        }
    }
}
