import PlayerzAPI
import SwiftUI

/// A booking in «Резервации»: when, where, its state and price (#359).
struct MyBookingSummary: View {
    let booking: Components.Schemas.MyBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(GameText.when(booking.startTs, timezone: booking.venue.timezone)).font(.headline)
            Text("\(booking.venue.name) · \(booking.resource.name)").font(.subheadline)
            HStack {
                Text(BookingCancel.status(booking.status))
                if booking.viewerRole == .PARTICIPANT {
                    Text(String(localized: "myBookings.added"))
                }
                Spacer()
                Text((Decimal(booking.totalCents) / 100).formatted(.currency(code: booking.currency)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
