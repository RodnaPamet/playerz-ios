import PlayerzAPI
import SwiftUI

/// One venue: its name, club and city, where it stands, and the terms or what
/// is still missing before lessons can be booked there.
struct CoachLinkRow: View {
    let link: Components.Schemas.MyCoachLink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(link.venue.name).font(Theme.Typography.rowTitle)
                Spacer()
                // The accent for a venue they teach at; the quiet grey for the rest.
                BrandBadge(CoachVenueText.status(link.status), style: link.status == .ACTIVE ? .accent : .neutral)
            }
            Text(String(localized: "coachVenues.at \(link.club.name) \(link.venue.city)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if link.status == .ACTIVE {
                if link.missing.contains(.courts) {
                    Text(String(localized: "coachVenues.missingCourts")).font(.footnote).foregroundStyle(Theme.Palette.danger)
                } else if !link.missing.isEmpty {
                    Text(String(localized: "coachVenues.missing")).font(.footnote).foregroundStyle(Theme.Palette.danger)
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
