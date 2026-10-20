import PlayerzAPI
import SwiftUI

/// The court tapped on the plan (#25). Free at the start showing: its time and
/// price, and «Резервирай». Taken: when it is free later that day, each time
/// a button that moves the plan there.
struct VenuePlanChoice: View {
    let court: VenueDetailModel.Court
    let start: Date
    let slot: Components.Schemas.AvailabilitySlot?
    let busySlot: Date?
    let book: (Components.Schemas.AvailabilitySlot) -> Void
    @Binding var chosen: Date?

    var body: some View {
        if let slot {
            let time = VenuePlanText.time(start)
            let price = VenuePlanText.price(slot.priceCents, court.currency)
            HStack {
                Text(verbatim: "\(court.name) · \(time) · \(price)")
                Spacer()
                Button {
                    book(slot)
                } label: {
                    if busySlot == slot.startTs {
                        ProgressView()
                    } else {
                        Text(String(localized: "venue.book"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busySlot != nil)
                .accessibilityLabel(
                    busySlot == slot.startTs
                        ? String(localized: "venue.booking")
                        : String(localized: "venuePlan.book \(court.name) \(time) \(price)")
                )
            }
        } else {
            let later = VenuePlanTimes.later(court.bookable.map(\.startTs), after: start)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "venuePlan.takenAt \(court.name) \(VenuePlanText.time(start))"))
                if later.isEmpty {
                    Text(String(localized: "venuePlan.noneLater \(court.name)"))
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "venuePlan.later")).foregroundStyle(.secondary)
                    HStack {
                        ForEach(later, id: \.self) { time in
                            Button(VenuePlanText.time(time)) { chosen = time }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
