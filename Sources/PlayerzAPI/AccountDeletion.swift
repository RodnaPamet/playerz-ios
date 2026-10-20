import Foundation
import OpenAPIRuntime

/// What asking to delete the account came to (`DELETE /me`, playerz-ios#9).
///
/// App Store guideline 5.1.1(v): an app that lets people make an account must
/// let them delete it in the app. The server decides everything: it refuses a
/// club account and an account with something still to play, and deletes
/// anything else at once, ending every session.
public enum AccountDeletion: Sendable, Equatable {
    /// Gone. Every session ended on the server, and this device is signed out.
    case deleted
    /// Something is still to be played, taught or entered: deal with it first.
    case blocked(UpcomingStanding)
    /// A club account is deleted on request, through the contact form.
    case clubAccount
    /// More than five attempts in an hour.
    case rateLimited
    /// Anything else, offline included. Nothing was deleted, or nothing is known.
    case failed
}

/// The `details` of `409 UPCOMING_BOOKINGS`: what stands in the way.
///
/// `bookings` is the first 25 of `total`. `role` and `cure` are open strings:
/// the server may add values, and a screen shows what it knows and a general
/// line for the rest.
public struct UpcomingStanding: Sendable, Equatable {
    public struct Booking: Sendable, Equatable, Identifiable {
        public let id: String
        /// `BOOKER` or `PARTICIPANT`.
        public let role: String
        /// `cancel` (until `cancellableUntil`), `leave` (until the start) or
        /// `wait` (deletion is possible from `deletableFrom`).
        public let cure: String
        public let start: Date
        public let end: Date
        public let cancellableUntil: Date?
        public let deletableFrom: Date?
    }

    public let total: Int
    /// Upcoming lessons the account teaches as a coach; not in `bookings`.
    public let lessons: Int
    /// Tournaments entered and not yet over.
    public let tournaments: Int
    public let bookings: [Booking]

    /// Read from the error's free-form `details`. Nil when they are not the
    /// shape `UPCOMING_BOOKINGS` documents, so a caller can say "failed"
    /// rather than show an empty list as a reason.
    init?(_ details: OpenAPIObjectContainer) {
        guard let data = try? JSONEncoder().encode(details),
            let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return nil }
        let dates = ServerDateTranscoder()
        func date(_ s: String?) -> Date? { s.flatMap { try? dates.decode($0) } }
        var bookings: [Booking] = []
        for b in raw.bookings ?? [] {
            guard let start = date(b.startTs), let end = date(b.endTs) else { return nil }
            bookings.append(
                Booking(
                    id: b.bookingId, role: b.role, cure: b.cure, start: start, end: end,
                    cancellableUntil: date(b.cancellableUntil), deletableFrom: date(b.deletableFrom)
                )
            )
        }
        self.total = raw.total
        self.lessons = raw.lessons ?? 0
        self.tournaments = raw.tournaments ?? 0
        self.bookings = bookings
    }

    private struct Raw: Decodable {
        struct Item: Decodable {
            let bookingId: String
            let role: String
            let cure: String
            let startTs: String
            let endTs: String
            let cancellableUntil: String?
            let deletableFrom: String?
        }
        let total: Int
        let lessons: Int?
        let tournaments: Int?
        let bookings: [Item]?
    }
}

/// Why `exportData()` has no file to give.
public enum DataExportError: Error, Equatable {
    case notSignedIn
    /// More than ten in an hour.
    case rateLimited
    /// Any other answer than 200, by its status.
    case refused(Int)
}
