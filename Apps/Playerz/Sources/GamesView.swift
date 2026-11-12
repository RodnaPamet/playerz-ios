import PlayerzAPI
import SwiftUI

/// «Открий» (#510): games looking for players as court cards, the caller's
/// own requests, and tournaments.
struct GamesView: View {
    @Bindable var session: SessionModel
    @State private var model = GamesModel()
    @State private var showing: Showing = DebugLaunch.gamesTournaments ? .tournaments : DebugLaunch.gamesMine ? .mine : .open
    /// A DEBUG launch can open a tournament straight away (DebugLaunch).
    @State private var path = NavigationPath(DebugLaunch.tournament.map { [TournamentRoute(id: $0)] } ?? [])
    @State private var pickingSport = DebugLaunch.gamesSheet == "sport"
    @State private var filtering = DebugLaunch.gamesSheet == "filters"
    @State private var asking: AskTarget?
    /// A refused request, said in an alert: a card has no line for it.
    @State private var problem: String?
    @State private var problemShown = false

    enum Showing: Hashable { case open, mine, tournaments }

    /// The game a «+» was tapped on.
    private struct AskTarget: Identifiable {
        let game: Components.Schemas.OpenGame
        var id: String { game.id }
    }

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
                    if showing == .open {
                        BrandFilterButton(label: String(localized: "games.filters"), count: model.activeFilters) {
                            filtering = true
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "games.tabs"))
            }
            .brandHeader(.title(String(localized: "tab.explore"))) {
                // The sport the open games are for, as the web's filter (#376).
                if showing == .open {
                    BrandHeaderPill(
                        title: model.sport.map(GameText.sport) ?? String(localized: "games.filter.sport"),
                        systemImage: model.sport.map(GameSport.symbol) ?? "sportscourt",
                        showsChevron: true
                    ) { pickingSport = true }
                }
            } actions: {
                BrandHeaderActions(session: session)
            }
            .brandSheet(isPresented: $pickingSport) { sportSheet }
            .brandSheet(isPresented: $filtering) {
                GamesFilterSheet(days: model.days, cities: model.cities, day: model.day, city: model.city) { day, city in
                    filtering = false
                    model.day = day
                    model.city = city
                }
            }
            // The keyboard needs room under the note, so this one does not hug its content.
            .brandSheet(item: $asking, detents: [.medium, .large]) { target in
                GameAskSheet(game: target.game, session: session) { outcome in
                    asking = nil
                    asked(outcome)
                }
            }
            .alert(problem ?? "", isPresented: $problemShown) {
                Button(String(localized: "common.close"), role: .cancel) {}
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
            await model.loadChoices(session)
            debugOpen()
        }
        .onChange(of: showing) { _, now in
            if now == .mine { Task { await model.loadMine(session) } }
        }
        // Back on this tab: a game opened or joined elsewhere is in the lists.
        .onShellTabReturn {
            await model.load(session)
            if showing == .mine { await model.loadMine(session) }
        }
        // A filter changed: the list is read again for it, once for all of them.
        .onChange(of: [model.sport, model.day?.apiDate, model.city]) { Task { await model.load(session) } }
    }

    // ─── Търсят играчи ────────────────────────────────────────────────

    @ViewBuilder private var openList: some View {
        switch model.phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            ) {
                if model.activeFilters > 0 || model.sport != nil {
                    Button(String(localized: "games.filters.clearAll")) {
                        model.sport = nil
                        model.day = nil
                        model.city = nil
                    }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                }
                // A game is opened from a booking, as «Създай» does it.
                Button(String(localized: "create.game.title")) { session.requestedTab = .bookings }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.l) {
                    ForEach(model.games, id: \.id) { game in
                        GameCard(
                            game: game,
                            server: session.serverURL,
                            open: { path.append(game) },
                            join: game.callerMayAsk ? { asking = AskTarget(game: game) } : nil
                        )
                        .onAppear {
                            if game.id == model.games.last?.id {
                                Task { await model.loadMore(session) }
                            }
                        }
                    }
                    if model.loadingMore {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await model.load(session) }
        }
    }

    /// The sports the listed clubs have courts for; the one chosen stays on
    /// the list even if no club offers it any more.
    private var sportSheet: some View {
        let sports = model.offeredSports + (model.sport.map { model.offeredSports.contains($0) ? [] : [$0] } ?? [])
        return BrandDarkSheet(
            title: String(localized: "games.sport.title"),
            subtitle: String(localized: "games.sport.subtitle")
        ) {
            BrandSheetRow(
                title: String(localized: "games.filter.allSports"),
                systemImage: "square.grid.2x2",
                isSelected: model.sport == nil
            ) { pick(nil) }
            ForEach(sports, id: \.self) { sport in
                BrandSheetRow(
                    title: GameText.sport(sport),
                    systemImage: GameSport.symbol(sport),
                    isSelected: model.sport == sport
                ) { pick(sport) }
            }
        }
    }

    private func pick(_ sport: String?) {
        pickingSport = false
        model.sport = sport
    }

    private func asked(_ outcome: GameAskSheet.Outcome) {
        switch outcome {
        case .asked(let game):
            model.replace(game)
            AccessibilityNotification.Announcement(GameText.status(game.viewer?.request?.status ?? .PENDING)).post()
            Task {
                await model.load(session)
                await model.loadMine(session)
            }
        case .refused(let text):
            problem = text
            problemShown = true
        case .cancelled:
            break
        }
    }

    /// A DEBUG launch on a game's screen, or with «Искам да играя» open (DebugLaunch).
    private func debugOpen() {
        if let id = DebugLaunch.game, path.isEmpty, let game = model.games.first(where: { $0.id == id }) {
            path.append(game)
        }
        if DebugLaunch.gamesSheet == "ask", asking == nil, let game = model.games.first(where: \.callerMayAsk) {
            asking = AskTarget(game: game)
        }
    }

    // ─── Моите заявки ────────────────────────────────────────────────

    @ViewBuilder private var mineList: some View {
        switch model.minePhase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            ) {
                Button(String(localized: "games.tab.open")) { showing = .open }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.l) {
                    ForEach(model.mine, id: \.id) { request in
                        GameCard(
                            game: request.game,
                            status: request.status,
                            server: session.serverURL,
                            open: { path.append(request.game) }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await model.loadMine(session) }
        }
    }
}
