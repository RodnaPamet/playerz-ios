import PlayerzAPI
import SwiftUI

/// One ranked player: place, name, level and matches.
struct ClubLeaderboardRow: View {
    let row: Components.Schemas.ClubLeaderboard.rowsPayloadPayload

    /// Grows with the text, so the place keeps its circle round around larger digits.
    @ScaledMetric(relativeTo: .subheadline) private var placeSide: CGFloat = 32
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // The place and the level on one line, the name under them with
                // the row's width: beside both it broke mid-word («Еле/на»).
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        place
                        Spacer(minLength: Theme.Spacing.s)
                        level
                    }
                    who
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    place
                    who
                    Spacer(minLength: Theme.Spacing.s)
                    level
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    // The first three on the accent, the rest on the chip grey: the number
    // itself says the place.
    private var place: some View {
        Text(row.rank.formatted())
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(row.rank <= 3 ? Theme.Palette.onAccent : Color.primary)
            .frame(minWidth: placeSide, minHeight: placeSide)
            .background(row.rank <= 3 ? Theme.Palette.accentFill : Theme.Palette.chipIdle, in: .circle)
    }

    private var who: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.name ?? String(localized: "club.leaderboard.unnamed"))
                .font(Theme.Typography.rowTitle)
            Text(String(localized: "club.leaderboard.matches \(row.matchesPlayed)"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var level: some View {
        Text(row.level.formatted(.number.precision(.fractionLength(1))))
            .font(Theme.Typography.cardTitle)
            .monospacedDigit()
            .foregroundStyle(Theme.Palette.accentText)
    }
}
