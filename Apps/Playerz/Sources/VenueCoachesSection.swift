import PlayerzAPI
import SwiftUI

/// «Треньори» on a venue (#19), as the web's venue page: the coaches a lesson
/// can be booked with here, each opening their page, and the full list.
struct VenueCoachesSection: View {
    let coaches: [Components.Schemas.PublicCoach]
    let venueId: String
    @Bindable var session: SessionModel

    var body: some View {
        Section(String(localized: "coaches.venue.title")) {
            ForEach(coaches, id: \.slug) { coach in
                NavigationLink {
                    CoachView(slug: coach.slug, session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CoachText.name(coach.name))
                        if let rate = coach.venues.first(where: { $0.venueId == venueId }) {
                            Text(String(localized: "coaches.venue.rate \(CoachText.money(rate.hourlyRateCents, rate.currency))"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            NavigationLink(String(localized: "coaches.venue.all")) {
                CoachesView(session: session)
            }
        }
    }
}
