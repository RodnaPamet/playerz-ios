import Foundation
import Observation
import PlayerzAPI

/// Игри (#510): the games looking for players, and the caller's own requests,
/// over the endpoints the web uses (#376).
@MainActor
@Observable
final class GamesModel {
    enum Phase { case loading, loaded, failed }
    enum Day: Hashable { case any, today, tomorrow }

    private(set) var phase: Phase = .loading
    private(set) var games: [Components.Schemas.OpenGame] = []
    private(set) var nextCursor: String?
    private(set) var loadingMore = false

    private(set) var minePhase: Phase = .loading
    private(set) var mine: [Components.Schemas.MyGameRequest] = []

    var sport: Components.Schemas.SportType?
    var day: Day = .any

    /// `date` is a day AT THE VENUE; a Sofia club's "today" is Sofia's. The
    /// pilot's clubs are all in one zone, so the strip is computed there.
    private static let zone = "Europe/Sofia"

    private var dateParam: String? {
        switch day {
        case .any: nil
        case .today: VenueDay.upcoming(inTimeZone: Self.zone).first?.apiDate
        case .tomorrow: VenueDay.upcoming(inTimeZone: Self.zone).dropFirst().first?.apiDate
        }
    }

    func load(_ session: SessionModel) async {
        phase = games.isEmpty ? .loading : phase
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client
                .listOpenGames(.init(query: .init(sport: sport, date: dateParam)))
                .ok.body.json.data
            games = page.items
            nextCursor = page.nextCursor
            phase = .loaded
        } catch {
            phase = .failed
        }
    }

    /// The next page, by the keyset cursor the last one returned.
    func loadMore(_ session: SessionModel) async {
        guard let cursor = nextCursor, !loadingMore, let client = await session.client() else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await client
                .listOpenGames(.init(query: .init(sport: sport, date: dateParam, cursor: cursor)))
                .ok.body.json.data
            // A game can move between pages while they are read; keep the first copy.
            let seen = Set(games.map(\.id))
            games += page.items.filter { !seen.contains($0.id) }
            nextCursor = page.nextCursor
        } catch {
            // The list stays as it is; scrolling to the end again retries.
        }
    }

    func loadMine(_ session: SessionModel) async {
        minePhase = mine.isEmpty ? .loading : minePhase
        guard let client = await session.client() else {
            minePhase = .failed
            return
        }
        do {
            mine = try await client.listMyGameRequests().ok.body.json.data
            minePhase = .loaded
        } catch {
            minePhase = .failed
        }
    }
}
