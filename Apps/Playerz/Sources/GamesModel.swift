import Foundation
import Observation
import PlayerzAPI

/// Игри (#510): the games looking for players, and the caller's own requests,
/// over the endpoints the web uses (#376).
@MainActor
@Observable
final class GamesModel {
    enum Phase { case loading, loaded, failed }

    private(set) var phase: Phase = .loading
    private(set) var games: [Components.Schemas.OpenGame] = []
    private(set) var nextCursor: String?
    private(set) var loadingMore = false

    private(set) var minePhase: Phase = .loading
    private(set) var mine: [Components.Schemas.MyGameRequest] = []

    var sport: String?
    /// The day at the venue, or any day.
    var day: VenueDay?
    var city: String?

    /// What the filters can offer: the server's venue facets (projectZ#667).
    private(set) var cities: [CityChoice] = []
    private(set) var offeredSports: [String] = Sports.known

    /// `date` is a day AT THE VENUE; a Sofia club's "today" is Sofia's. The
    /// pilot's clubs are all in one zone, so the strip is computed there.
    static let zone = "Europe/Sofia"

    /// Games are listed 14 days ahead, so those are the days worth offering.
    var days: [VenueDay] { VenueDay.upcoming(inTimeZone: Self.zone) }

    var activeFilters: Int { (day == nil ? 0 : 1) + (city == nil ? 0 : 1) }

    private var dateParam: String? { day?.apiDate }

    func load(_ session: SessionModel) async {
        phase = games.isEmpty ? .loading : phase
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client
                .listOpenGames(.init(query: .init(sport: sport, date: dateParam, city: city)))
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
                .listOpenGames(.init(query: .init(sport: sport, date: dateParam, city: city, cursor: cursor)))
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

    /// The cities and sports the server's venues have, once: what the sport
    /// sheet and the city filter offer. A failure leaves the known sports and no cities.
    func loadChoices(_ session: SessionModel) async {
        guard cities.isEmpty, let client = await session.client(),
              let facets = await VenueFacetChoices.load(client) else { return }
        cities = facets.cities
        if !facets.sports.isEmpty { offeredSports = facets.sports }
    }

    /// A game the server just answered with (a request sent): shown at once,
    /// before the lists are read again.
    func replace(_ game: Components.Schemas.OpenGame) {
        if let index = games.firstIndex(where: { $0.id == game.id }) { games[index] = game }
    }
}
