import PlayerzAPI
import SwiftUI

/// Past the club's cancellation cutoff: when it passed, and the club's phone
/// to change the booking, as the web says it.
struct BookingCutoffPassed: View {
    let booking: Components.Schemas.MyBookingDetail

    var body: some View {
        Section {
            if let until = booking.cancellableUntil {
                Text(String(localized: "myBookings.detail.cutoffPassed \(GameText.when(until, timezone: booking.venue.timezone))"))
            } else {
                Text(String(localized: "myBookings.detail.cutoffPassedNoDate"))
            }
            if let phone = booking.venue.phone, let call = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                Link(String(localized: "myBookings.detail.callClub \(phone)"), destination: call)
            } else {
                Text(String(localized: "myBookings.detail.contactClub")).foregroundStyle(.secondary)
            }
        }
    }
}
