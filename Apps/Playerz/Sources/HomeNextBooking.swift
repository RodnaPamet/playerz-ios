import PlayerzAPI
import SwiftUI

/// The player's next booking on «Начало»: when, where, and how it stands.
/// A label: the home screen wraps it in the link to the booking.
struct HomeNextBookingCard: View {
    let booking: Components.Schemas.MyBooking

    var body: some View {
        BrandContentCard {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(minWidth: 48, minHeight: 48)
                    .background(Theme.Palette.accentFill, in: .rect(cornerRadius: Theme.Radius.tile))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.nextBooking"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accentText)
                    // On the venue's clock, as in «Резервации».
                    Text(GameText.when(booking.startTs, timezone: booking.venue.timezone))
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(Color.primary)
                    Text("\(booking.venue.name) · \(booking.resource.name)")
                        .font(Theme.Typography.cardSubtitle)
                        .foregroundStyle(.secondary)
                    // A held, unpaid booking is the one that needs a tap.
                    Text(BookingCancel.status(booking.status))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
