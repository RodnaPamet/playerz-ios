import Foundation
import Observation
import PlayerzAPI

/// What the club list is narrowed by. Only what the server can really apply:
/// `GET /venues` takes a city, a sport and indoor/outdoor.
struct VenueFilters: Equatable {
    var city: String?
    var sport: String?
    /// True indoor, false outdoor, nil either.
    var indoor: Bool?

    /// How many are on. «Близо до мен» is searched by sport alone
    /// (`/venues/near` takes nothing else), so only that one counts there.
    func count(near: Bool) -> Int {
        let sportOn = sport == nil ? 0 : 1
        if near { return sportOn }
        return sportOn + (city == nil ? 0 : 1) + (indoor == nil ? 0 : 1)
    }
}

@MainActor
@Observable
final class VenueListModel {
    enum Phase { case loading, loaded, failed, locating, locationDenied }
    enum Mode { case all, near }

    /// A row either way, so the list does not need two branches.
    struct Row: Identifiable {
        let id: String
        let name: String
        let city: String
        let country: String
        let fromPriceCents: Int?
        /// Only present in `near` mode.
        let distanceKm: Double?
        /// Empty in `near` mode: that endpoint names no sports.
        let sports: [String]
        let avgRating: Double
        let reviewCount: Int
        /// Nil in `near` mode, and for a club with no photo.
        let cover: Components.Schemas.VenuePhoto?
    }

    private(set) var phase: Phase = .loading
    private(set) var rows: [Row] = []
    private(set) var mode: Mode = .all
    private(set) var filters = VenueFilters()
    /// The cities and sports to offer in the filter: those of the clubs the
    /// unfiltered list returned, so every option finds at least one club.
    private(set) var cities: [String] = []
    private(set) var sports: [String] = []
    private var nextCursor: String?

    private let location = LocationProvider()

    var activeFilterCount: Int { filters.count(near: mode == .near) }

    func setMode(_ mode: Mode, session: SessionModel) async {
        guard mode != self.mode || rows.isEmpty else { return }
        self.mode = mode
        await load(session)
    }

    func apply(_ filters: VenueFilters, session: SessionModel) async {
        guard filters != self.filters else { return }
        self.filters = filters
        await load(session)
    }

    /// «Всички»: every club, nothing narrowed.
    func showEverything(_ session: SessionModel) async {
        guard mode != .all || filters != VenueFilters() || rows.isEmpty else { return }
        mode = .all
        filters = VenueFilters()
        await load(session)
    }

    /// `quiet` keeps the cards on show while it reads: a pull to refresh.
    func load(_ session: SessionModel, quiet: Bool = false) async {
        let quiet = quiet && phase == .loaded
        guard let client = await session.client() else {
            phase = .failed
            return
        }

        do {
            switch mode {
            case .all:
                if !quiet { phase = .loading }
                // Discovery is public — BearerMiddleware exempts it, so this
                // works signed out and does not widen what a browse correlates
                // with.
                let page = try await client.listVenues(query: query(cursor: nil)).ok.body.json.data
                rows = page.items.map(Self.row)
                nextCursor = page.nextCursor
                if filters == VenueFilters() { remember(page.items) }

            case .near:
                if !quiet { phase = .locating }
                let here = try await location.current()

                if !quiet { phase = .loading }
                let result = try await client.findVenuesNear(
                    .init(
                        query: .init(
                            lat: here.latitude,
                            lng: here.longitude,
                            // Named radiusKm, not radius, and silently clamped
                            // to 50 rather than rejected — so asking for more
                            // would quietly mean 50 anyway.
                            radiusKm: 50,
                            sport: filters.sport
                        )
                    )
                ).ok.body.json.data
                nextCursor = nil
                rows = result.venues.map {
                    Row(
                        id: $0.id, name: $0.name, city: $0.city, country: $0.country,
                        // /venues/near carries no price, sports or photo; the
                        // card omits them rather than showing wrong ones.
                        fromPriceCents: nil, distanceKm: $0.distanceKm,
                        sports: [], avgRating: $0.avgRating, reviewCount: $0.reviewCount, cover: nil
                    )
                }
            }
            phase = .loaded
        } catch LocationProvider.Failure.denied {
            // Recoverable only in Settings, so say which switch, not "error".
            phase = .locationDenied
        } catch {
            phase = .failed
        }
    }

    /// The next page, when the last card comes on screen.
    func loadMore(_ session: SessionModel) async {
        guard mode == .all, let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        let asked = filters
        guard let page = try? await client.listVenues(query: query(cursor: cursor)).ok.body.json.data,
              // The filters changed while it was on its way: not this list's page.
              asked == filters, mode == .all
        else { return }
        let seen = Set(rows.map(\.id))
        rows += page.items.map(Self.row).filter { !seen.contains($0.id) }
        nextCursor = page.nextCursor
        if filters == VenueFilters() { remember(page.items) }
    }

    private func query(cursor: String?) -> Operations.listVenues.Input.Query {
        // 50 is the server's ceiling for a page.
        .init(city: filters.city, sport: filters.sport, indoor: filters.indoor, cursor: cursor, limit: 50)
    }

    private func remember(_ items: [Components.Schemas.VenueSummary]) {
        cities = Array(Set(cities + items.map(\.city))).sorted { $0.localizedCompare($1) == .orderedAscending }
        let found = Set(sports + items.flatMap(\.sports))
        // The server's order for the sports this build names, then any other.
        sports = Sports.known.filter(found.contains) + found.subtracting(Sports.known).sorted()
    }

    private static func row(_ venue: Components.Schemas.VenueSummary) -> Row {
        Row(
            id: venue.id, name: venue.name, city: venue.city, country: venue.country,
            fromPriceCents: venue.fromPriceCents, distanceKm: nil,
            sports: venue.sports, avgRating: venue.avgRating, reviewCount: venue.reviewCount, cover: venue.cover
        )
    }
}
