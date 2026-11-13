import PlayerzAPI
import SwiftUI

/// «Профил» → «Мачове» (playerz-ios#95): counted matches, newest first, with
/// the score from the player's side and what each did to the level.
struct StatsMatchesView: View {
    let model: StatsModel
    let session: SessionModel

    var body: some View {
        switch model.matchesPhase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await model.loadMatches(session) }
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "stats.failed")) {
                Button(String(localized: "venues.retry")) { Task { await model.loadMatches(session) } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where model.matches.isEmpty:
            BrandEmptyState(
                systemImage: "sportscourt",
                title: String(localized: "stats.matches.empty"),
                message: String(localized: "stats.empty.hint")
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(model.matches, id: \.matchId) { match in
                        StatsMatchCard(match: match)
                            .onAppear {
                                if match.matchId == model.matches.last?.matchId {
                                    Task { await model.loadMoreMatches(session) }
                                }
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .refreshable { await model.loadMatches(session) }
        }
    }
}

/// One match: when and where, the result, the score, who with and against,
/// and the level's move.
struct StatsMatchCard: View {
    let match: Components.Schemas.MyMatch

    var body: some View {
        let outcome = match.outcome.rawValue
        BrandContentCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(StatsText.day(match.playedAt))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accentText)
                    Spacer()
                    Text(StatsText.outcome(outcome).uppercased())
                        .font(Theme.Typography.badge)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, 3)
                        .foregroundStyle(outcome == "DRAW" ? Color.primary : Theme.Palette.onAccent)
                        .background(
                            outcome == "WIN" ? Theme.Palette.success : outcome == "LOSS" ? Theme.Palette.danger : Theme.Palette.chipIdle,
                            in: .capsule
                        )
                }
                Text(match.score.map(StatsText.score) ?? String(localized: "stats.matches.noScore"))
                    .font(Theme.Typography.display(32, relativeTo: .title2))
                    .monospacedDigit()
                if !match.partners.isEmpty {
                    Label(String(localized: "stats.matches.with \(StatsText.names(match.partners))"), systemImage: "person.2")
                        .font(.subheadline)
                }
                if !match.opponents.isEmpty {
                    Label(String(localized: "stats.matches.against \(StatsText.names(match.opponents))"), systemImage: "figure.fencing")
                        .font(.subheadline)
                }
                HStack {
                    if let venue = match.venue {
                        Label(venue.name, systemImage: "building.2").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let tournament = match.tournament {
                        Label(tournament.name, systemImage: "trophy").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let change = StatsFacts.change(from: match.levelBefore, to: match.levelAfter) {
                        Text(StatsText.change(change))
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(change > 0 ? Theme.Palette.success : change < 0 ? Theme.Palette.danger : .secondary)
                            .accessibilityLabel(String(localized: "stats.matches.levelChange \(StatsText.change(change))"))
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
