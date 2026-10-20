import PlayerzAPI
import SwiftUI

/// Where: the address, directions in Maps, and the venue's own screen.
struct BookingDetailPlace: View {
    let booking: Components.Schemas.MyBookingDetail
    @Bindable var session: SessionModel

    var body: some View {
        Section(String(localized: "myBookings.detail.address")) {
            Text("\(booking.venue.addressLine), \(booking.venue.city)")
            if let directions {
                Link(destination: directions) {
                    Label(String(localized: "myBookings.detail.directions"), systemImage: "map")
                }
            }
            NavigationLink(String(localized: "myBookings.detail.venuePage")) {
                VenueDetailView(venueId: booking.venue.id, session: session)
            }
        }
    }

    /// Apple Maps, driving to the venue's point, labelled with its name.
    private var directions: URL? {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(booking.venue.lat),\(booking.venue.lng)"),
            URLQueryItem(name: "q", value: booking.venue.name),
        ]
        return parts?.url
    }
}
