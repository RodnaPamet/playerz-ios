import PlayerzAPI
import SwiftUI

/// «Класиране» in Профил (playerz-ios#18), the web's `MyRatingsSection`: each
/// sport's level as others see it, and what only the player sees: the
/// engine's points and the confirmed matches behind them. Only while the
/// ranking module is on.
struct MyRatingsSection: View {
    @Bindable var session: SessionModel

    @State private var ratings: Components.Schemas.MyRatings?

    var body: some View {
        Section {
            if let ratings {
                if ratings.items.isEmpty {
                    Text(String(localized: "profile.ratings.none")).foregroundStyle(.secondary)
                }
                ForEach(ratings.items, id: \.sport) { rating in
                    LabeledContent(GameText.sport(rating.sport)) {
                        VStack(alignment: .trailing) {
                            Text(RatingText.level(rating.level, provisional: rating.provisional))
                            Text(points(rating)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        } header: {
            Text(String(localized: "profile.ratings.title"))
        } footer: {
            if let ratings {
                Text(ratings._public ? String(localized: "profile.ratings.hint") : String(localized: "profile.ratings.hintHidden"))
            }
        }
        .task { await load() }
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
