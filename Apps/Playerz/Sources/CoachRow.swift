import PlayerzAPI
import SwiftUI

/// A coach in a list: their picture or initials, name, rating, sports, and
/// the lowest rate.
struct CoachRow: View {
    let coach: Components.Schemas.PublicCoach
    let serverURL: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            BrandAvatar(name: coach.name, url: GameText.picture(coach.avatarUrl, server: serverURL), side: 52)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(CoachText.name(coach.name))
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(Color.primary)
                Text(coach.sports.map { GameText.sport($0.sport) }.formatted(.list(type: .and)))
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(.secondary)
                ChipFlow {
                    if let from = coach.fromRateCents {
                        VenueFactChip(text: String(localized: "coaches.from \(CoachText.money(from, coach.currency))"), prominent: true)
                    }
                    if let rating = CoachText.rating(coach.rating) {
                        // The words carry their own star («4,6 ★ (12)»).
                        VenueFactChip(text: rating)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
