import PlayerzAPI
import SwiftUI

/// «Турнири» in Игри (playerz-ios#22), as the web's games page: the player's
/// own tournaments, then the ones open for entries now. Only while the
/// ranking module is on.
struct TournamentsList: View {
    @Bindable var session: SessionModel

    @State private var mine: [Components.Schemas.TournamentView] = []
    @State private var open: [Components.Schemas.Tournament] = []
    @State private var phase: Phase = .loading

    enum Phase { case loading, loaded, failed }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView(String(localized: "common.loading"))
            case .failed:
                ContentUnavailableView {
                    Text(String(localized: "games.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            case .loaded where mine.isEmpty && open.isEmpty:
                ContentUnavailableView(
                    String(localized: "tournaments.none"),
                    systemImage: "trophy",
                    description: Text(String(localized: "tournaments.noneHint"))
                )
            case .loaded:
                List {
                    if !mine.isEmpty {
                        Section(String(localized: "tournaments.mine")) {
                            ForEach(mine, id: \.value1.id) { view in
                                NavigationLink(value: TournamentRoute(id: view.value1.id)) {
                                    TournamentRow(tournament: view.value1, entry: view.value2.myEntry)
                                }
                            }
                        }
                    }
                    if !open.isEmpty {
                        Section(String(localized: "tournaments.open")) {
                            ForEach(open, id: \.id) { tournament in
                                NavigationLink(value: TournamentRoute(id: tournament.id)) {
                                    TournamentRow(tournament: tournament, entry: nil)
                                }
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .task { await load() }
    }

    private func retry() {
        phase = .loading
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            async let entries = client.listMyTournamentEntries().ok.body.json.data.items
            async let listed = client.listOpenTournaments().ok.body.json.data.items
            mine = try await entries
            let shown = Set(mine.map(\.value1.id))
            open = try await listed.filter { !shown.contains($0.id) }
            phase = .loaded
        } catch {
            phase = mine.isEmpty && open.isEmpty ? .failed : .loaded
        }
    }
}
