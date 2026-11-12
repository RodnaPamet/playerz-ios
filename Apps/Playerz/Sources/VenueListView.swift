import PlayerzAPI
import SwiftUI

/// «Начало»: what to do as large tiles, the player's next booking, then the
/// clubs as cards under their cover, narrowed by the chips and «Филтри».
struct VenueListView: View {
    @Bindable var session: SessionModel
    @State private var model = VenueListModel()
    @State private var debugClub: String? = DebugLaunch.club
    @State private var debugVenue: String? = DebugLaunch.venue
    /// «Треньори» on show: from the header's pill, «Създай», or a DEBUG launch.
    @State private var showingCoaches = DebugLaunch.coaches
    @State private var showingTournaments = false
    @State private var filtering = DebugLaunch.home == "filters"
    /// Changed to start the stack again from the club list.
    @State private var stackID = 0
    @State private var debugCoach: String? = DebugLaunch.coach
    /// «Резервирай корт» asked for the clubs: scroll there once the page is up.
    @State private var clubsWanted = DebugLaunch.home == "clubs"
    /// The soonest upcoming booking; nil with none, or while unread.
    @State private var nextBooking: Components.Schemas.MyBooking?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let clubsAnchor = "clubs"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        HomeActionGrid(modules: session.modules, run: run)
                        if let nextBooking {
                            NavigationLink {
                                BookingDetailView(bookingId: nextBooking.id, session: session)
                            } label: {
                                HomeNextBookingCard(booking: nextBooking)
                            }
                            .buttonStyle(.brandCard)
                        }
                        clubsHeader
                            .id(Self.clubsAnchor)
                        clubs
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                }
                .refreshable {
                    await model.load(session, quiet: true)
                    await loadNextBooking()
                }
                // Not while the clubs are still being read: there is nothing
                // under the title to scroll up yet.
                .onChange(of: clubsWanted && model.phase != .loading, initial: true) { _, ready in
                    guard ready else { return }
                    clubsWanted = false
                    // A turn later: on a stack just rebuilt the rows are not laid out yet.
                    Task {
                        withAnimation(reduceMotion ? nil : .snappy) {
                            proxy.scrollTo(Self.clubsAnchor, anchor: .top)
                        }
                    }
                }
            }
            .navigationDestination(item: $debugClub) { slug in
                ClubView(slug: slug, session: session)
            }
            .navigationDestination(item: $debugVenue) { id in
                VenueDetailView(venueId: id, session: session)
            }
            .brandPage()
            .navigationDestination(isPresented: $showingCoaches) {
                CoachesView(session: session)
            }
            .navigationDestination(item: $debugCoach) { slug in
                CoachView(slug: slug, session: session)
            }
            // «Турнири» as «Открий» lists them, for the tile here.
            .navigationDestination(isPresented: $showingTournaments) {
                TournamentsList(session: session)
                    .brandPage()
                    .brandHeader(.back(String(localized: "games.tab.tournaments")))
            }
            .navigationDestination(for: TournamentRoute.self) { route in
                TournamentDetailView(id: route.id, session: session)
            }
            // Hidden with the system bar, but still what a pushed screen's back button says.
            .navigationTitle(String(localized: "tab.home"))
            .brandHeader(.wordmark) {
                // «Треньори» (#19), while the coaches module is on.
                if session.modules.coaches {
                    BrandHeaderPill(title: String(localized: "coaches.title"), systemImage: "figure.tennis") {
                        showingCoaches = true
                    }
                }
            } actions: {
                BrandHeaderActions(session: session)
            }
        }
        .id(stackID)
        .task {
            await model.load(session)
            await loadNextBooking()
        }
        // Back on this tab: a court booked or cancelled elsewhere changes the card.
        .onShellTabReturn { await loadNextBooking() }
        // «Създай» asked for the club list or «Треньори»; `initial`, for a
        // request made before this tab was first opened.
        .onChange(of: session.homeRequest, initial: true) { _, request in
            guard let request else { return }
            session.homeRequest = nil
            debugClub = nil
            debugVenue = nil
            debugCoach = nil
            showingTournaments = false
            showingCoaches = request == .coaches && session.modules.coaches
            clubsWanted = request == .clubs
            stackID += 1
        }
        .brandSheet(isPresented: $filtering) {
            VenueFilterSheet(
                filters: model.filters, cities: model.cities, sports: model.sports, near: model.mode == .near
            ) { chosen in
                filtering = false
                Task { await model.apply(chosen, session: session) }
            }
        }
    }

    private func run(_ action: HomeActionGrid.Action) {
        switch action {
        case .court: clubsWanted = true
        // A game is opened from a booking («Търся играчи»), as «Създай» has it.
        case .createGame: session.requestedTab = .bookings
        case .findGames: session.requestedTab = .games
        case .lesson: showingCoaches = true
        case .tournaments: showingTournaments = true
        }
    }

    private func loadNextBooking() async {
        guard let client = await session.client() else { return }
        // `upcoming` is soonest first, so one row is the next one.
        guard let page = try? await client
            .listMyBookings(.init(query: .init(limit: 1, when: .upcoming)))
            .ok.body.json.data
        else { return }
        nextBooking = page.items.first
    }

    // MARK: Clubs

    /// «Клубове» and what narrows them. In the page, not pinned under the
    /// header: the tiles above are not clubs, and the chips do not act on them.
    private var clubsHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(String(localized: "venues.title"))
                    .font(Theme.Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Theme.Spacing.s)
                // At the largest text the button would cover most of the chip row.
                if typeSize.isAccessibilitySize { filterButton }
            }
            BrandChipRow {
                filterChips
            } trailing: {
                if !typeSize.isAccessibilitySize { filterButton }
            }
            // The row brings its own side margin; the page has one already.
            .padding(.horizontal, -Theme.Spacing.l)
        }
    }

    private var filterButton: some View {
        BrandFilterButton(label: String(localized: "venues.filters"), count: model.activeFilterCount) {
            filtering = true
        }
    }

    @ViewBuilder private var filterChips: some View {
        BrandChip(
            String(localized: "venues.all"),
            isSelected: model.mode == .all && model.activeFilterCount == 0
        ) {
            Task { await model.showEverything(session) }
        }
        BrandChip(String(localized: "venues.nearMe"), systemImage: "location", isSelected: model.mode == .near) {
            Task { await model.setMode(.near, session: session) }
        }
        // What is on, by name; the sheet changes it.
        if model.mode == .all, let city = model.filters.city {
            BrandChip(city, systemImage: "mappin", isSelected: true) { filtering = true }
        }
        if let sport = model.filters.sport {
            BrandChip(GameText.sport(sport), isSelected: true) { filtering = true }
        }
        if model.mode == .all, let indoor = model.filters.indoor {
            BrandChip(
                String(localized: indoor ? "venues.filter.indoor" : "venues.filter.outdoor"),
                isSelected: true
            ) { filtering = true }
        }
    }

    @ViewBuilder private var clubs: some View {
        switch model.phase {
        case .loading:
            ProgressView(String(localized: "common.loading")).frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.xl)
        case .locating:
            ProgressView(String(localized: "venues.locating")).frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.xl)
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "venues.failed")) {
                Button(String(localized: "venues.retry")) {
                    Task { await model.load(session) }
                }
                .buttonStyle(.brandSecondary(fullWidth: false))
            }
            // Under the tiles, in the page's own scroll view.
            .inline()
        case .locationDenied:
            BrandEmptyState(
                systemImage: "location.slash",
                title: String(localized: "venues.nearMe"),
                message: String(localized: "venues.noLocation")
            )
            .inline()
        case .loaded where model.rows.isEmpty:
            BrandEmptyState(systemImage: "figure.tennis", title: emptyTitle).inline()
        case .loaded:
            ForEach(model.rows) { row in
                NavigationLink {
                    VenueDetailView(venueId: row.id, session: session)
                } label: {
                    VenueCard(row: row, serverURL: session.serverURL)
                }
                .buttonStyle(.brandCard)
                .onAppear {
                    if row.id == model.rows.last?.id { Task { await model.loadMore(session) } }
                }
            }
        }
    }

    private var emptyTitle: String {
        if model.activeFilterCount > 0 { return String(localized: "venues.noMatch") }
        return model.mode == .near ? String(localized: "venues.noneNearby") : String(localized: "venues.empty")
    }
}

/// One club: its cover (the club's photo, or a drawn band while it has none),
/// its initial, its name, where it is, and what is known of it as chips.
private struct VenueCard: View {
    let row: VenueListModel.Row
    let serverURL: String

    var body: some View {
        BrandCoverCard(coverHeight: 132) {
            VenueCover(photo: row.cover, seed: row.id, serverURL: serverURL)
        } logo: {
            VenueLogoTile(name: row.name)
        } content: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(row.name)
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Color.primary)
                    // The whole name: in the lazy stack it was cut to one
                    // line with "…" at the accessibility sizes.
                    .fixedSize(horizontal: false, vertical: true)
                // A separate "·" Text is read as its own fragment by VoiceOver and
                // wraps badly at large sizes. One string instead.
                Label(placeLine, systemImage: "mappin.and.ellipse")
                    .labelStyle(.titleAndIcon)
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ChipFlow {
                    if let priceLine {
                        VenueFactChip(text: priceLine, prominent: row.fromPriceCents != nil)
                    }
                    if let rating {
                        VenueFactChip(text: rating.shown, systemImage: "star.fill")
                    }
                    ForEach(VenueFacts.sports(row.sports), id: \.self) { sport in
                        VenueFactChip(text: sport)
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .multilineTextAlignment(.leading)
        }
        // One utterance per club. Left alone, VoiceOver reads each chip as a
        // fragment, and a bare "4,5 (12)" says nothing.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var rating: (shown: String, spoken: String)? {
        VenueFacts.rating(row.avgRating, count: row.reviewCount)
    }

    private var spoken: String {
        ([row.name, placeLine] + [priceLine, rating?.spoken].compactMap { $0 } + VenueFacts.sports(row.sports))
            .joined(separator: ", ")
    }

    private var placeLine: String {
        let place = [row.city, row.country].joined(separator: ", ")
        guard let km = row.distanceKm else { return place }
        let distance = String(
            format: String(localized: "venues.distance"),
            km.formatted(.number.precision(.fractionLength(1)))
        )
        return "\(place) · \(distance)"
    }

    /// Nil in `near` mode — that endpoint carries no price, and inventing one
    /// is worse than omitting it.
    ///
    /// In `all` mode a null `fromPriceCents` means the club has no bookable
    /// court. NOT zero: the server's DTO comment is explicit that 0 would
    /// render as "free".
    private var priceLine: String? {
        guard row.distanceKm == nil else { return nil }
        guard let cents = row.fromPriceCents else {
            return String(localized: "venues.noPrice")
        }
        return VenueFacts.price(fromCents: cents)
    }
}
