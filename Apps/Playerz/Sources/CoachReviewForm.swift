import PlayerzAPI
import SwiftUI

/// «Оцени треньора» (#19): the coach's review, after a lesson. One per coach.
struct CoachReviewForm: View {
    let bookingId: String
    @Bindable var session: SessionModel
    let done: () -> Void

    var body: some View {
        ReviewForm(
            title: String(localized: "myBookings.review.coach.rate"),
            ratingLabel: String(localized: "myBookings.review.coach.ratingLabel"),
            maxLength: 1000,
            send: send,
            done: done
        )
    }

    private func send(_ rating: Int, _ body: String?) async -> String? {
        guard let client = await session.client() else { return BookingPlayerText.reviewError(nil) }
        let response = try? await client.reviewMyLessonCoach(
            path: .init(id: bookingId),
            body: .json(.init(rating: rating, body: body))
        )
        if case .created = response { return nil }
        return BookingPlayerText.reviewError(response.flatMap { apiErrorCode($0) })
    }
}
