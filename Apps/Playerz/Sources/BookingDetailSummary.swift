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
                        Text(String(localized: "myBookings.detail.lesson.partsOf \(money(lesson.coachFeeCents)) \(money(lesson.courtPriceCents)) \(PlaceText.of(PlaceWord.of(booking.resource.sport)))"))
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
            LabeledContent(
                String(localized: "myBookings.detail.status"),
                value: BookingCancel.status(booking.status, isMatch: booking.tournamentMatch != nil)
            )
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

    /// The place's word for its sport (PlaceWord, owner 2026-11-13).
    private var courtLabel: String {
        PlaceText.label(sport: booking.resource.sport)
    }
}
