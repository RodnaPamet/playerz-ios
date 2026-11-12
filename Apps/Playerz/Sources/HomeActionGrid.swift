import PlayerzAPI
import SwiftUI

/// The first thing on «Начало»: what a player comes to do, as large tiles.
/// «Резервирай корт» across the top, the rest two to a row. A module the
/// server has off has no tile (#16).
struct HomeActionGrid: View {
    enum Action: Hashable { case court, createGame, findGames, lesson, tournaments }

    let modules: Modules
    let run: (Action) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            tile(.court)
            ForEach(Self.rows(Self.secondary(modules), paired: !typeSize.isAccessibilitySize), id: \.self) { row in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ForEach(row, id: \.self) { tile($0) }
                }
                // As tall as the taller one, so a pair reads as one row.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ action: Action) -> some View {
        Button {
            run(action)
        } label: {
            BrandActionCard(
                title: title(action),
                subtitle: subtitle(action),
                systemImage: symbol(action),
                style: action == .createGame ? .accent : .dark,
                minHeight: action == .court ? 150 : 140,
                fillsHeight: true
            )
            // A court drawn on the wide tile's free half. Decoration only,
            // so it goes when large text needs that half.
            .overlay(alignment: .trailing) {
                if action == .court, !typeSize.isAccessibilitySize {
                    Image(systemName: "sportscourt")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.light)
                        .foregroundStyle(Theme.Palette.onHeader.opacity(0.1))
                        .rotationEffect(.degrees(-10))
                        .padding(Theme.Spacing.l)
                        .frame(maxWidth: 190)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.brandCard)
    }

    // MARK: Pure parts

    /// The tiles under «Резервирай корт», each while its module is on.
    /// Tournaments are part of the ranking module.
    nonisolated static func secondary(_ modules: Modules) -> [Action] {
        var actions: [Action] = []
        if modules.openPlay { actions += [.createGame, .findGames] }
        if modules.coaches { actions.append(.lesson) }
        if modules.ranking { actions.append(.tournaments) }
        return actions
    }

    /// Two to a row, an odd last one across; one to a row at the text sizes
    /// where two would squeeze their titles.
    nonisolated static func rows(_ actions: [Action], paired: Bool) -> [[Action]] {
        guard paired else { return actions.map { [$0] } }
        return stride(from: 0, to: actions.count, by: 2).map { Array(actions[$0 ..< min($0 + 2, actions.count)]) }
    }

    private func title(_ action: Action) -> String {
        switch action {
        case .court: String(localized: "create.court.title")
        case .createGame: String(localized: "create.game.title")
        case .findGames: String(localized: "home.games.title")
        case .lesson: String(localized: "create.lesson.title")
        case .tournaments: String(localized: "games.tab.tournaments")
        }
    }

    private func subtitle(_ action: Action) -> String {
        switch action {
        case .court: String(localized: "create.court.subtitle")
        case .createGame: String(localized: "create.game.subtitle")
        case .findGames: String(localized: "home.games.subtitle")
        case .lesson: String(localized: "create.lesson.subtitle")
        case .tournaments: String(localized: "home.tournaments.subtitle")
        }
    }

    private func symbol(_ action: Action) -> String {
        switch action {
        case .court: "calendar.badge.plus"
        case .createGame: "person.2.badge.plus"
        case .findGames: "person.3"
        case .lesson: "figure.tennis"
        case .tournaments: "trophy"
        }
    }
}

#Preview {
    ScrollView {
        HomeActionGrid(modules: .unknown) { _ in }.padding()
    }
    .brandPage()
}
