import PlayerzAPI
import SwiftUI

/// One ranked player: place, name, level and matches.
struct ClubLeaderboardRow: View {
    let row: Components.Schemas.ClubLeaderboard.rowsPayloadPayload

    /// Grows with the text, so the place keeps its circle round around larger digits.
    @ScaledMetric(relativeTo: .subheadline) private var placeSide: CGFloat = 32

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // The first three on the accent, the rest on the chip grey: the
            // number itself says the place.
            Text(row.rank.formatted())
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? Theme.Palette.onAccent : Color.primary)
                .frame(minWidth: placeSide, minHeight: placeSide)
                .background(row.rank <= 3 ? Theme.Palette.accentFill : Theme.Palette.chipIdle, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name ?? String(localized: "club.leaderboard.unnamed"))
                    .font(Theme.Typography.rowTitle)
                Text(String(localized: "club.leaderboard.matches \(row.matchesPlayed)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.s)
            Text(row.level.formatted(.number.precision(.fractionLength(1))))
                .font(Theme.Typography.cardTitle)
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.accentText)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
