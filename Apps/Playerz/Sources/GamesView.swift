import PlayerzAPI
import SwiftUI

/// The Игри tab (#510): games looking for players, and «Моите заявки».
struct GamesView: View {
    @Bindable var session: SessionModel
    @State private var model = GamesModel()
    @State private var showing: Showing = DebugLaunch.gamesTournaments ? .tournaments : DebugLaunch.gamesMine ? .mine : .open
    /// A DEBUG launch can open a tournament straight away (DebugLaunch).
    @State private var path = NavigationPath(DebugLaunch.tournament.map { [TournamentRoute(id: $0)] } ?? [])
    @State private var pickingSport = false

    enum Showing: Hashable { case open, mine, tournaments }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch showing {
                case .open: openList
                case .mine: mineList
                case .tournaments: TournamentsList(session: session)
                }
            }
            .brandPage()
            // Hidden with the system bar, but still what a pushed screen's back button says.
            .navigationTitle(String(localized: "games.title"))
            .brandChipBar {
                BrandChipRow {
                    BrandChip(String(localized: "games.tab.open"), isSelected: showing == .open) { showing = .open }
                    BrandChip(String(localized: "games.tab.mine"), isSelected: showing == .mine) { showing = .mine }
                    // «Турнири» (#22), while the ranking module is on.
                    if session.modules.ranking {
                        BrandChip(String(localized: "games.tab.tournaments"), isSelected: showing == .tournaments) {
                            showing = .tournaments
                        }
                    }
                } trailing: {
                    if showing == .open { filters }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "games.tabs"))
            }
            .brandHeader(.title(String(localized: "tab.explore"))) {
                // The sport the open games are for, as the web's filter (#376).
                if showing == .open {
                    BrandHeaderPill(
                        title: model.sport.map(GameText.sport) ?? String(localized: "games.filter.sport"),
                        systemImage: "sportscourt",
                        showsChevron: true
                    ) { pickingSport = true }
                }
            } actions: {
                BrandHeaderActions(session: session)
            }
            .brandSheet(isPresented: $pickingSport) {
                BrandDarkSheet(
                    title: String(localized: "games.sport.title"),
                    subtitle: String(localized: "games.sport.subtitle")
                ) {
                    BrandSheetRow(
                        title: String(localized: "games.filter.allSports"),
                        systemImage: "square.grid.2x2",
                        isSelected: model.sport == nil
                    ) { pick(nil) }
                    ForEach(Sports.known, id: \.self) { sport in
                        BrandSheetRow(
                            title: GameText.sport(sport),
                            systemImage: "sportscourt",
                            isSelected: model.sport == sport
                        ) { pick(sport) }
                    }
                }
            }
            .navigationDestination(for: TournamentRoute.self) { route in
                TournamentDetailView(id: route.id, session: session)
            }
            .navigationDestination(for: Components.Schemas.OpenGame.self) { game in
                GameDetailView(game: game, session: session) {
                    await model.load(session)
                    await model.loadMine(session)
                }
            }
        }
        .task {
            await model.load(session)
            if showing == .mine { await model.loadMine(session) }
        }
        .onChange(of: showing) { _, now in
            if now == .mine { Task { await model.loadMine(session) } }
        }
        // Back on this tab: a game opened or joined elsewhere is in the lists.
        .onShellTabReturn {
            await model.load(session)
            if showing == .mine { await model.loadMine(session) }
        }
        // A filter changed: the list is read again for it.
        .onChange(of: model.day) { Task { await model.load(session) } }
        .onChange(of: model.sport) { Task { await model.load(session) } }
    }

    // ─── Търсят играчи ────────────────────────────────────────────────

    @ViewBuilder private var openList: some View {
        switch model.phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "games.failed")) {
                Button(String(localized: "venues.retry")) { Task { await model.load(session) } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where model.games.isEmpty:
            BrandEmptyState(
                systemImage: "person.3",
                title: String(localized: "games.empty"),
                message: String(localized: "games.emptyHint")
            )
        case .loaded:
            List {
                ForEach(model.games, id: \.id) { game in
                    NavigationLink(value: game) { GameRow(game: game) }
                        .onAppear {
                            if game.id == model.games.last?.id {
                                Task { await model.loadMore(session) }
                            }
                        }
                }
                .brandListRow()
                if model.loadingMore {
                    ProgressView().frame(maxWidth: .infinity).brandListRow()
                }
            }
            .refreshable { await model.load(session) }
        }
    }

    /// The day, as the web's filter (#376); a change reloads the list. The
    /// sport is the header's pill.
    private var filters: some View {
        Menu {
            Picker(String(localized: "games.filter.day"), selection: $model.day) {
                Text(String(localized: "games.filter.anyDay")).tag(GamesModel.Day.any)
                Text(String(localized: "venue.today")).tag(GamesModel.Day.today)
                Text(String(localized: "games.filter.tomorrow")).tag(GamesModel.Day.tomorrow)
            }
        } label: {
            BrandFilterLabel(count: model.day == .any ? 0 : 1)
        }
        .accessibilityLabel(String(localized: "games.filters"))
        .accessibilityValue(model.day == .any ? "" : "1")
    }

    private func pick(_ sport: String?) {
        pickingSport = false
        model.sport = sport
    }

    // ─── Моите заявки ────────────────────────────────────────────────

    @ViewBuilder private var mineList: some View {
        switch model.minePhase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "games.mine.failed")) {
                Button(String(localized: "venues.retry")) { Task { await model.loadMine(session) } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where model.mine.isEmpty:
            BrandEmptyState(
                systemImage: "hand.raised",
                title: String(localized: "games.mine.empty"),
                message: String(localized: "games.mine.emptyHint")
            )
        case .loaded:
            List(model.mine, id: \.id) { request in
                NavigationLink(value: request.game) {
                    VStack(alignment: .leading, spacing: 4) {
                        GameRow(game: request.game)
                        Text(GameText.status(request.status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(request.status == .ACCEPTED ? .green : .secondary)
                    }
                }
                .brandListRow()
            }
            .refreshable { await model.loadMine(session) }
        }
    }
}

/// One game: where and when, the sport, how many are wanted, the level wish.
struct GameRow: View {
    let game: Components.Schemas.OpenGame

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GameText.when(game.startTs, timezone: game.timezone)).font(.headline)
            Text("\(GameText.sport(game.sport)) · \(game.venue.name), \(game.venue.city)")
                .font(.subheadline)
            HStack(spacing: 8) {
                Text(String(localized: "games.spotsLeft \(game.spotsLeft)"))
                Text(GameText.level(min: game.levelMin, max: game.levelMax))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            if game.viewer?.levelFits == true {
                Text(String(localized: "games.levelFits"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
