import PlayerzAPI
import SwiftUI

/// The venue's review, as the web's list puts it: the review left against THIS
/// booking, with where it stands; on another played booking at a venue already
/// reviewed, that it is; else the form, once the server says it may be sent.
struct BookingDetailReview: View {
    let booking: Components.Schemas.MyBookingDetail
    @Bindable var session: SessionModel
    let reviewed: () -> Void

    var body: some View {
        if let review = booking.venueReview, review.bookingId == booking.id {
            Section {
                LabeledContent(String(localized: "myBookings.review.yours \(review.rating)"), value: status(review.status))
            }
        } else if booking.venueReview != nil, booking.status == "COMPLETED" {
            Section {
                Text(String(localized: "myBookings.review.alreadyThisVenue")).foregroundStyle(.secondary)
            }
        } else if booking.canReview, let clubSlug = booking.clubSlug {
            Section {
                NavigationLink(String(localized: "myBookings.review.rate")) {
                    VenueReviewForm(clubSlug: clubSlug, bookingId: booking.id, session: session, done: reviewed)
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
