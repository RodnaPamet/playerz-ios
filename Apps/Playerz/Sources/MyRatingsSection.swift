import PlayerzAPI
import SwiftUI

/// «Класиране» in Профил (playerz-ios#18), the web's `MyRatingsSection`: each
/// sport's level as others see it, and what only the player sees: the
/// engine's points and the confirmed matches behind them. Only while the
/// ranking module is on.
struct MyRatingsSection: View {
    @Bindable var session: SessionModel
    /// Changed by the screen to have the levels read again.
    var reload = 0

    @State private var ratings: Components.Schemas.MyRatings?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // No header: the band over the screen already says «Класиране».
        Section {
            if let ratings {
                if ratings.items.isEmpty {
                    Text(String(localized: "profile.ratings.none")).foregroundStyle(.secondary)
                }
                ForEach(ratings.items, id: \.sport) { rating in
                    row(rating)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        } footer: {
            if let ratings {
                Text(ratings._public ? String(localized: "profile.ratings.hint") : String(localized: "profile.ratings.hintHidden"))
            }
        }
        .task(id: reload) { await load() }
    }

    /// The sport's tile, then its name, the level and the points under it:
    /// one column, so the level («Ниво 4,0 (неокончателно)») is never squeezed
    /// beside the name.
    private func row(_ rating: Components.Schemas.MyRatings.itemsPayloadPayload) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            // At the accessibility sizes the words need the width: the tile
            // says nothing the sport's name does not.
            if !typeSize.isAccessibilitySize {
                Image(systemName: GameSport.symbol(rating.sport))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accentText)
                    .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                    .background(Theme.Palette.chipIdle, in: .rect(cornerRadius: Theme.Radius.tile))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(GameText.sport(rating.sport)).font(Theme.Typography.rowTitle)
                Text(RatingText.level(rating.level, provisional: rating.provisional))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accentText)
                Text(points(rating)).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func points(_ rating: Components.Schemas.MyRatings.itemsPayloadPayload) -> String {
        guard let points = rating.points else { return String(localized: "profile.ratings.noMatches") }
        let shown = points.formatted(.number.precision(.fractionLength(0...1)))
        return String(localized: "profile.ratings.points \(shown) \(rating.matchesPlayed)")
    }

    private func load() async {
        guard let client = await session.client() else { return }
        if let fresh = try? await client.getMyRatings().ok.body.json.data { ratings = fresh }
    }
}
