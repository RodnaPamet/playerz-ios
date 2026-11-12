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
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "games.failed")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            case .loaded where mine.isEmpty && open.isEmpty:
                BrandEmptyState(
                    systemImage: "trophy",
                    title: String(localized: "tournaments.none"),
                    message: String(localized: "tournaments.noneHint")
                )
            case .loaded:
                // Cards on the page, as the games beside them in «Открий».
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        if !mine.isEmpty {
                            heading(String(localized: "tournaments.mine"))
                            ForEach(mine, id: \.value1.id) { view in
                                card(view.value1, entry: view.value2.myEntry)
                            }
                        }
                        if !open.isEmpty {
                            heading(String(localized: "tournaments.open"))
                                .padding(.top, mine.isEmpty ? 0 : Theme.Spacing.s)
                            ForEach(open, id: \.id) { tournament in
                                card(tournament, entry: nil)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                }
                .refreshable { await load() }
            }
        }
        .task { await load() }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.sectionTitle)
            .accessibilityAddTraits(.isHeader)
    }

    /// The whole card opens the tournament.
    private func card(_ tournament: Components.Schemas.Tournament, entry: Components.Schemas.MyTournamentEntry?) -> some View {
        NavigationLink(value: TournamentRoute(id: tournament.id)) {
            BrandContentCard {
                TournamentRow(tournament: tournament, entry: entry)
            }
        }
        .buttonStyle(.brandCard)
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
