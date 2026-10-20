import PlayerzAPI
import SwiftUI

/// One venue on a club's page: its name, where it is, and its sports.
struct ClubVenueRow: View {
    let venue: Components.Schemas.ClubPublic.venuesPayloadPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(venue.name).font(.headline)
            Text("\(venue.addressLine), \(venue.city)")
                .foregroundStyle(.secondary)
            if !venue.sports.isEmpty {
                Text(venue.sports.map { localized(key: "sport.\($0)") }.formatted(.list(type: .and)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "club.sportsLabel"))
                    .accessibilityValue(venue.sports.map { localized(key: "sport.\($0)") }.formatted(.list(type: .and)))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
