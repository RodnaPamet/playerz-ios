import PlayerzAPI
import SwiftUI

/// A tournament in a list: its name and kind, when and where, the places, the
/// fee, and the player's entry if they have one.
struct TournamentRow: View {
    let tournament: Components.Schemas.Tournament
    let entry: Components.Schemas.MyTournamentEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(tournament.name).font(.headline)
                Spacer()
                Text(entry.map { TournamentText.entry($0.status) } ?? TournamentText.status(tournament))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(TournamentText.kind(tournament)).font(.subheadline)
            Text(TournamentText.dates(tournament)).font(.subheadline)
            Text("\(tournament.venue?.name ?? tournament.club.name) · \(TournamentText.places(tournament)) · \(TournamentText.fee(tournament))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
