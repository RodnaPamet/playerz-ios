import PlayerzAPI
import SwiftUI

/// A booking in «Резервации» (#359): the day and the hours first, then the
/// club and the court, its state as a badge, and the price.
struct MyBookingSummary: View {
    let booking: Components.Schemas.MyBooking

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // The badge beside the day, or under it when both do not fit.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    day
                    Spacer(minLength: Theme.Spacing.s)
                    badges
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    day
                    badges
                }
            }
            Text(Self.hours(booking.startTs, booking.endTs, timezone: booking.venue.timezone))
                .font(Theme.Typography.cardTitle)
                .monospacedDigit()
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(booking.venue.name, systemImage: "building.2")
                    .font(Theme.Typography.rowTitle)
                Label(booking.resource.name, systemImage: "sportscourt")
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                if booking.viewerRole == .PARTICIPANT {
                    Text(String(localized: "myBookings.added"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(price)
                    .font(Theme.Typography.rowTitle)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    private var day: some View {
        Text(Self.day(booking.startTs, timezone: booking.venue.timezone))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Palette.accentText)
    }

    private var badges: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if booking.lesson != nil {
                BrandBadge(String(localized: "myBookings.lesson"), style: .neutral)
            }
            BrandBadge(BookingCancel.status(booking.status), style: Self.badgeStyle(booking.status))
        }
    }

    /// A lesson's whole price, not only the court's part of it (#548).
    private var price: String {
        let cents = booking.lesson?.totalCents ?? booking.totalCents
        return (Decimal(cents) / 100).formatted(.currency(code: booking.currency))
    }

    /// The word says the state; the fill only sorts live from over.
    nonisolated static func badgeStyle(_ status: String) -> BrandBadgeStyle {
        switch status {
        case "CONFIRMED": .accent
        case "PENDING": .ink
        default: .neutral
        }
    }

    /// «четвъртък, 12 ноември», on the VENUE's clock (GameText.when).
    nonisolated static func day(_ date: Date, timezone: String) -> String {
        date.formatted(
            Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
                .weekday(.wide).day().month(.wide)
        )
    }

    /// «19:00 – 20:30», on the venue's clock.
    nonisolated static func hours(_ start: Date, _ end: Date, timezone: String) -> String {
        let clock = Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
            .hour(.twoDigits(amPM: .omitted)).minute()
        return "\(start.formatted(clock)) – \(end.formatted(clock))"
    }
}
