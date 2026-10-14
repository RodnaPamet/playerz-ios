import PlayerzAPI
import SwiftUI

/// The Игри tab (#510): games looking for players, and «Моите заявки».
struct GamesView: View {
    @Bindable var session: SessionModel
    @State private var model = GamesModel()
    @State private var showing: Showing = DebugLaunch.gamesMine ? .mine : .open

    enum Showing: Hashable { case open, mine }

    var body: some View {
        NavigationStack {
            Group {
                switch showing {
                case .open: openList
                case .mine: mineList
                }
            }
            .navigationTitle(String(localized: "games.title"))
            // Inline: with a segmented control inset below the bar, iOS 26 hid the large
            // title under the bar's material.
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                Picker(String(localized: "games.tabs"), selection: $showing) {
                    Text(String(localized: "games.tab.open")).tag(Showing.open)
                    Text(String(localized: "games.tab.mine")).tag(Showing.mine)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 4)
                .background(.bar)
            }
            .toolbar {
                if showing == .open {
                    ToolbarItem(placement: .topBarTrailing) { filters }
                }
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
            ContentUnavailableView {
                Text(String(localized: "games.failed"))
            } actions: {
                Button(String(localized: "venues.retry")) { Task { await model.load(session) } }
            }
        case .loaded where model.games.isEmpty:
            ContentUnavailableView(
                String(localized: "games.empty"),
                systemImage: "person.3",
                description: Text(String(localized: "games.emptyHint"))
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
                if model.loadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .refreshable { await model.load(session) }
        }
    }

    /// Sport and day, as the web's filters (#376); a change reloads the list.
    private var filters: some View {
        Menu {
            Picker(String(localized: "games.filter.day"), selection: $model.day) {
                Text(String(localized: "games.filter.anyDay")).tag(GamesModel.Day.any)
                Text(String(localized: "venue.today")).tag(GamesModel.Day.today)
                Text(String(localized: "games.filter.tomorrow")).tag(GamesModel.Day.tomorrow)
            }
            Picker(String(localized: "games.filter.sport"), selection: $model.sport) {
                Text(String(localized: "games.filter.allSports"))
                    .tag(Components.Schemas.SportType?.none)
                ForEach(Components.Schemas.SportType.allCases, id: \.self) { sport in
                    Text(GameText.sport(sport)).tag(Optional(sport))
                }
            }
        } label: {
            Label(String(localized: "games.filters"), systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    // ─── Моите заявки ────────────────────────────────────────────────

    @ViewBuilder private var mineList: some View {
        switch model.minePhase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            ContentUnavailableView {
                Text(String(localized: "games.mine.failed"))
            } actions: {
                Button(String(localized: "venues.retry")) { Task { await model.loadMine(session) } }
            }
        case .loaded where model.mine.isEmpty:
            ContentUnavailableView(
                String(localized: "games.mine.empty"),
                systemImage: "hand.raised",
                description: Text(String(localized: "games.mine.emptyHint"))
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
