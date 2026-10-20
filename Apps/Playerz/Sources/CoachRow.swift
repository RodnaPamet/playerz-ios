import PlayerzAPI
import SwiftUI

/// A coach in a list: name, rating, sports, and the lowest rate.
struct CoachRow: View {
    let coach: Components.Schemas.PublicCoach

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(CoachText.name(coach.name)).font(.headline)
                Spacer()
                if let rating = CoachText.rating(coach.rating) {
                    Text(rating).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(coach.sports.map { GameText.sport($0.sport) }.formatted(.list(type: .and)))
                .font(.subheadline)
            if let from = coach.fromRateCents {
                Text(String(localized: "coaches.from \(CoachText.money(from, coach.currency))"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
