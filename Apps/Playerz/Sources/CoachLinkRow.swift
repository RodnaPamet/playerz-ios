import PlayerzAPI
import SwiftUI

/// One venue: its name, club and city, where it stands, and the terms or what
/// is still missing before lessons can be booked there.
struct CoachLinkRow: View {
    let link: Components.Schemas.MyCoachLink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(link.venue.name).font(.headline)
                Spacer()
                Text(CoachVenueText.status(link.status)).font(.footnote).foregroundStyle(.secondary)
            }
            Text(String(localized: "coachVenues.at \(link.club.name) \(link.venue.city)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if link.status == .ACTIVE {
                if link.missing.contains(.courts) {
                    Text(String(localized: "coachVenues.missingCourts")).font(.footnote).foregroundStyle(.orange)
                } else if !link.missing.isEmpty {
                    Text(String(localized: "coachVenues.missing")).font(.footnote).foregroundStyle(.orange)
                } else if let rate = link.hourlyRateCents {
                    let lengths = link.lessonMinutes.map(String.init).formatted(.list(type: .and, width: .narrow))
                    Text(String(localized: "coachVenues.summary \(CoachText.money(rate, link.currency)) \(lengths)"))
                        .font(.footnote)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
