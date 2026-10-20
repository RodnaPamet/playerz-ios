import PlayerzAPI
import SwiftUI

/// Where a coach teaches: the venue, its club and city, the rates, the lengths.
struct CoachVenueRow: View {
    let venue: Components.Schemas.PublicCoachVenue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(venue.name).font(.headline)
            Text(String(localized: "coaches.page.at \(venue.club.name) \(venue.city)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(rates).font(.subheadline)
            Text(String(localized: "coaches.page.lengths \(lengths)"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// «60, 90».
    private var lengths: String {
        venue.lessonMinutes.map(String.init).formatted(.list(type: .and, width: .narrow))
    }

    private var rates: String {
        let one = String(localized: "coaches.page.rate \(CoachText.money(venue.hourlyRateCents, venue.currency))")
        guard let group = venue.groupRateCents else { return one }
        return "\(one) · \(String(localized: "coaches.page.groupRate \(CoachText.money(group, venue.currency))"))"
    }
}
