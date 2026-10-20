import PlayerzAPI
import SwiftUI

/// When, which court, the price and how it is paid, and the booking's state;
/// for a lesson, the coach and the price in its two parts.
struct BookingDetailSummary: View {
    let booking: Components.Schemas.MyBookingDetail

    var body: some View {
        Section {
            LabeledContent(String(localized: "myBookings.detail.when")) {
                Text(GameText.when(booking.startTs, timezone: booking.venue.timezone))
            }
            LabeledContent(courtLabel, value: booking.resource.name)
            if let lesson = booking.lesson {
                LabeledContent(
                    String(localized: "myBookings.detail.lesson.coach"),
                    value: lesson.coach.name ?? String(localized: "myBookings.detail.lesson.noName")
                )
                LabeledContent(String(localized: "myBookings.detail.price")) {
                    VStack(alignment: .trailing) {
                        Text(money(lesson.totalCents))
                        Text(String(localized: "myBookings.detail.lesson.parts \(money(lesson.coachFeeCents)) \(money(lesson.courtPriceCents))"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        payAtClub
                    }
                }
            } else {
                LabeledContent(String(localized: "myBookings.detail.price")) {
                    VStack(alignment: .trailing) {
                        Text(money(booking.totalCents))
                        payAtClub
                    }
                }
            }
            LabeledContent(String(localized: "myBookings.detail.status"), value: BookingCancel.status(booking.status))
        }
    }

    @ViewBuilder private var payAtClub: some View {
        if booking.payAtClub {
            Text(String(localized: "myBookings.detail.payAtClub"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func money(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: booking.currency))
    }

    /// The web's noun for the resource (resource-kinds.ts); a type added later
    /// reads as a court.
    private var courtLabel: String {
        switch booking.resource.resourceType {
        case "FIELD": String(localized: "myBookings.detail.pitch.court")
        case "TABLE", "BOARD_TABLE": String(localized: "myBookings.detail.table.court")
        case "LOBBY": String(localized: "myBookings.detail.seat.court")
        case "TRACK": String(localized: "myBookings.detail.track.court")
        default: String(localized: "myBookings.detail.court")
        }
    }
}
