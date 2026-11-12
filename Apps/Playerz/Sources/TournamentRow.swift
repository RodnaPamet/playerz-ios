import PlayerzAPI
import SwiftUI

/// A tournament in a list: its name and kind, when and where, the places, the
/// fee, and the player's entry if they have one. The content only: a card in
/// «Турнири», a row on a club's page.
struct TournamentRow: View {
    let tournament: Components.Schemas.Tournament
    let entry: Components.Schemas.MyTournamentEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // The badge beside the name, or under it when both do not fit.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    name
                    Spacer(minLength: Theme.Spacing.s)
                    badge
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    name
                    badge
                }
            }
            Text(TournamentText.kind(tournament))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.accentText)
            Label(TournamentText.dates(tournament), systemImage: "calendar")
                .font(Theme.Typography.cardSubtitle)
            Label(tournament.venue?.name ?? tournament.club.name, systemImage: "building.2")
                .font(Theme.Typography.cardSubtitle)
            Text("\(TournamentText.places(tournament)) · \(TournamentText.fee(tournament))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        Text(tournament.name).font(Theme.Typography.rowTitle)
    }

    private var badge: some View {
        if let entry {
            BrandBadge(TournamentText.entry(entry.status), style: Self.badgeStyle(entry.status))
        } else {
            BrandBadge(TournamentText.status(tournament), style: Self.badgeStyle(tournament))
        }
    }

    /// The word says the state; the fill only sorts live from over, as a booking's badge.
    nonisolated static func badgeStyle(_ status: Components.Schemas.MyTournamentEntry.statusPayload) -> BrandBadgeStyle {
        switch status {
        case .CONFIRMED: .accent
        case .PENDING: .ink
        case .DECLINED, .WITHDRAWN: .neutral
        }
    }

    nonisolated static func badgeStyle(_ tournament: Components.Schemas.Tournament) -> BrandBadgeStyle {
        switch tournament.status {
        case .REGISTRATION: tournament.entriesOpen ? .accent : .ink
        case .IN_PROGRESS: .ink
        case .DRAFT, .COMPLETE, .CANCELLED: .neutral
        }
    }
}
