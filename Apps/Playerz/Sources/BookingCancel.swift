import Foundation
import PlayerzAPI

/// A player cancelling their booking, and the line that says what follows:
/// shared by a club's list and «Резервации».
enum BookingCancel {
    /// `clubSlug` is the CLUB's: `/t/{slug}` is the club's namespace, and a
    /// venue's slug is unique only within its club.
    static func run(
        _ session: SessionModel,
        clubSlug: String,
        bookingId: String,
        currency: String
    ) async -> (text: String, isError: Bool) {
        guard let client = await session.client() else {
            return (String(localized: "bookings.cancelFailed"), true)
        }
        do {
            // The body is optional and a body-less POST is the common case.
            let response = try await client.cancelBooking(
                .init(path: .init(slug: clubSlug, id: bookingId))
            )
            switch response {
            case let .ok(ok):
                return (refundLine(try ok.body.json.data, currency: currency), false)
            case .conflict:
                // Already cancelled. Each call writes a fresh receipt, so the
                // server refuses rather than silently agreeing.
                return (String(localized: "bookings.already"), true)
            default:
                // Someone else's booking answers 404, never 403: a 403 would
                // confirm it exists. Nothing to distinguish here on purpose.
                return (String(localized: "bookings.cancelFailed"), true)
            }
        } catch {
            return (String(localized: "bookings.cancelFailed"), true)
        }
    }

    /// ═══ "DUE", NEVER "REFUNDED" ═══
    ///
    /// The endpoint cancels the booking and writes a Cancellation receipt with
    /// the resolved percentage frozen onto it. It does NOT move money — issuing
    /// the refund is a separate operation — and the spec instructs clients in
    /// as many words not to say "refunded", only "refund of X due".
    private static func refundLine(_ quote: Components.Schemas.CancelQuote, currency: String) -> String {
        guard quote.refundAmountCents > 0 else {
            return String(localized: "bookings.noRefund")
        }
        let amount = (Decimal(quote.refundAmountCents) / 100).formatted(.currency(code: currency))
        return String(format: String(localized: "bookings.refundDue"), amount)
    }

    /// A booking's status in the web's words; the raw value for one added later.
    static func status(_ raw: String) -> String {
        let known: Set<String> = ["PENDING", "CONFIRMED", "CANCELLED", "COMPLETED", "NO_SHOW"]
        return known.contains(raw) ? localized(key: "bookings.status.\(raw)") : raw
    }
}
