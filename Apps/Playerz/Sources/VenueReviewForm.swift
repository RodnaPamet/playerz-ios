import PlayerzAPI
import SwiftUI

/// «Оцени обекта» (#14): the venue's review, after a played booking.
struct VenueReviewForm: View {
    let clubSlug: String
    let bookingId: String
    @Bindable var session: SessionModel
    let done: () -> Void

    var body: some View {
        ReviewForm(
            title: String(localized: "myBookings.review.rate"),
            ratingLabel: String(localized: "myBookings.review.ratingLabel"),
            maxLength: 2000,
            send: send,
            done: done
        )
    }

    private func send(_ rating: Int, _ body: String?) async -> String? {
        guard let client = await session.client() else { return BookingPlayerText.reviewError(nil) }
        let response = try? await client.reviewBooking(
            path: .init(slug: clubSlug, id: bookingId),
            body: .json(.init(rating: rating, body: body))
        )
        if case .created = response { return nil }
        return BookingPlayerText.reviewError(response.flatMap { apiErrorCode($0) })
    }
}
