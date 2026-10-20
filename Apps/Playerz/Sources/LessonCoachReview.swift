import PlayerzAPI
import SwiftUI

/// The coach's review on a lesson's booking (#19): the player's own, with
/// where it stands, or the form once the lesson is played and the server says
/// it may be sent. One per coach, so it may have been left after another lesson.
struct LessonCoachReview: View {
    let bookingId: String
    let lesson: Components.Schemas.MyBookingLesson
    @Bindable var session: SessionModel
    let reviewed: () -> Void

    var body: some View {
        if let review = lesson.myReview {
            Section {
                LabeledContent(
                    String(localized: "myBookings.review.coach.yours \(review.rating)"),
                    value: status(review.status)
                )
            }
        } else if lesson.canReview {
            Section {
                NavigationLink(String(localized: "myBookings.review.coach.rate")) {
                    CoachReviewForm(bookingId: bookingId, session: session, done: reviewed)
                }
            }
        }
    }

    private func status(_ raw: String) -> String {
        ["PUBLISHED", "PENDING_REVIEW", "REJECTED"].contains(raw)
            ? localized(key: "myBookings.review.status.\(raw)")
            : raw
    }
}
