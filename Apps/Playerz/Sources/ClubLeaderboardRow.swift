import PlayerzAPI
import SwiftUI

/// One ranked player: place, name, level and matches.
struct ClubLeaderboardRow: View {
    let row: Components.Schemas.ClubLeaderboard.rowsPayloadPayload

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(row.rank.formatted())
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
            VStack(alignment: .leading) {
                Text(row.name ?? String(localized: "club.leaderboard.unnamed"))
                Text(String(localized: "club.leaderboard.matches \(row.matchesPlayed)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(row.level.formatted(.number.precision(.fractionLength(1))))
                .monospacedDigit()
                .bold()
        }
        .accessibilityElement(children: .combine)
    }
}
