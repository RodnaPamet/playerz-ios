import PlayerzAPI
import SwiftUI

struct VenueDetailView: View {
    let venueId: String
    @Bindable var session: SessionModel
    @State private var model = VenueDetailModel()
    @State private var offerPush = false
    @State private var conversation: OpenedConversation?
    @State private var writeProblem: String?
    @State private var showingWriteProblem = false
    /// A DEBUG launch can open the club's bookings (`PLAYERZ_OPEN=bookings`).
    @State private var showingBookings = DebugLaunch.open == "bookings"
    /// The heart (projectZ#672); nil until read.
    @State private var favourite: Bool?
    /// The name is on the cover card; the header carries it only once the card is scrolled away (#55).
    @State private var heroShown = true
    /// The court whose times show (owner 2026-11-13): chosen on the plan or
    /// the picker; the first with a free time until then.
    @State private var selectedCourt: String?
    /// The summary of the hours picked (owner 2026-11-13).
    @State private var reviewing = false
    /// A place opened from the picker: its hours on their own screen.
    @State private var openedPlace: PlaceRoute?

    struct PlaceRoute: Hashable, Identifiable {
        let id: String
    }
    /// The coaches teaching here (#19), while the coaches module is on.
    @State private var coaches: [Components.Schemas.PublicCoach] = []

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView(String(localized: "common.loading"))
            case .failed:
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "venue.failed")) {
                    Button(String(localized: "venues.retry")) {
                        Task { await model.load(session, venueId: venueId) }
                    }
                    .buttonStyle(.brandSecondary(fullWidth: false))
                }
            case .loaded:
                content
            }
        }
        // The hours picked, above the tab bar, until they are reserved.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.picks.isEmpty {
                PicksBar(
                    count: model.picks.count,
                    totalCents: model.picksTotalCents,
                    currency: model.picks.first?.currency ?? "EUR",
                    next: { reviewing = true },
                    clear: { model.clearPicks() }
                )
            }
        }
        .navigationDestination(item: $openedPlace) { route in
            PlaceHoursView(model: model, session: session, venueId: venueId, resourceIds: pickerOrder, start: route.id)
        }
        .onChange(of: model.summaryOpen) { _, open in
            // The offer a summary held back (here or on a place's screen),
            // now that it has closed.
            if !open, model.lastBookingSucceeded { offerPushIfUndecided() }
        }
        .sheet(isPresented: $reviewing) {
            ReservationSheet(model: model, session: session, venueId: venueId, venueName: model.venue?.name ?? "")
                .outsideShellBar()
        }
        .brandPage()
        // The screen the assistant is told about (#122).
        .assistantPage(.venue(venueId))
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(model.venue?.name ?? "")
        .navigationDestination(isPresented: $showingBookings) {
            if let slug = model.venue?.clubSlug {
                BookingsView(slug: slug, session: session)
            }
        }
        // The days stay under the header while a day's hours load, so the
        // strip keeps its place instead of going away with the list.
        .brandChipBar {
            if model.days.count > 1 {
                BrandChipRow {
                    ForEach(model.days) { day in
                        BrandChip(
                            // «Днес», «Утре», «сб, 14.11»: as the games' day filter says it.
                            GameText.filterDay(day, zone: model.timezone),
                            isSelected: day.apiDate == model.selectedDate
                        ) {
                            Task { await model.select(session, venueId: venueId, day: day) }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "venue.dayPicker"))
            }
        }
        .task { await loadFavourite() }
        .brandHeader(.back(heroShown ? "" : model.venue?.name ?? "")) {
            if let favourite {
                // The band's own round button, as its neighbours; the filled heart says it is on.
                BrandHeaderButton(
                    systemImage: favourite ? "heart.fill" : "heart",
                    label: String(localized: favourite ? "favourites.remove" : "favourites.add")
                ) { Task { await toggleFavourite() } }
                .accessibilityAddTraits(favourite ? .isSelected : [])
            }
            // The CLUB's slug: `/t/{slug}/bookings` is the club's namespace, and
            // a venue's slug matches it only when the club named it so.
            if model.venue?.clubSlug != nil {
                BrandHeaderButton(systemImage: "calendar", label: String(localized: "bookings.title")) {
                    showingBookings = true
                }
            }
            // «Пиши на клуба» (#484): the club's conversation, by the club's slug;
            // not while the server has messaging off (#16).
            if session.modules.messaging, let club = model.venue?.clubSlug {
                BrandHeaderButton(systemImage: "bubble.left", label: String(localized: "messages.writeToClub")) {
                    Task { await writeToClub(club) }
                }
            }
        }
        .sheet(item: $conversation) { opened in
            ConversationSheet(opened: opened, session: session).outsideShellBar()
        }
        .alert(
            String(localized: "messages.writeToClub"),
            isPresented: $showingWriteProblem,
            presenting: writeProblem
        ) { _ in
        } message: { problem in
            Text(problem)
        }
        .task {
            await model.load(session, venueId: venueId)
            await loadCoaches()
            // DEBUG only: hours picked and the summary open, for a screenshot.
            if DebugLaunch.place != nil, model.courts.count > 1, let court = model.courts.first(where: { !$0.bookable.isEmpty }) {
                openedPlace = PlaceRoute(id: court.resourceId)
            }
            if let count = DebugLaunch.pick, let court = model.courts.first(where: { !$0.bookable.isEmpty }) {
                for slot in court.bookable.prefix(count) { model.toggle(court, slot) }
                reviewing = DebugLaunch.review && DebugLaunch.place == nil
            }
        }
        // A new day, or the first read: keep the court chosen while it is there.
        .onChange(of: model.courts.map(\.resourceId) + model.courts.map { "\($0.bookable.count)" }, initial: true) {
            selectedCourt = VenueCourtPicker.initial(model.courts, keeping: selectedCourt)
        }
        .onChange(of: model.banner) { _, banner in
            // A banner appearing mid-list is invisible to VoiceOver: focus does
            // not move, and the user is told nothing about the booking they
            // just made.
            guard let banner else { return }
            AccessibilityNotification.Announcement(banner).post()
        }
        .onChange(of: model.lastBookingSucceeded) { _, booked in
            // Only after a booking, and only once: iOS grants exactly one
            // system prompt, so it is spent at the moment the offer is
            // concrete rather than on a cold launch. Not while the summary is
            // open: an alert here would close it over its payment step.
            guard booked, !model.summaryOpen else { return }
            offerPushIfUndecided()
        }
        .alert(String(localized: "push.askTitle"), isPresented: $offerPush) {
            Button(String(localized: "push.allow")) {
                Task { await PushRegistrar.shared.requestAndRegister(session) }
            }
            // "Not now" is recoverable; a system "Don't Allow" is not. Asking
            // ourselves first is what preserves the one real prompt.
            Button(String(localized: "push.notNow"), role: .cancel) {}
        } message: {
            Text(String(localized: "push.askBody"))
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollViewReader { proxy in
        List {
            if let venue = model.venue {
                Section {
                    VenueHero(venue: venue, serverURL: session.serverURL)
                        .onAppear { heroShown = true }
                        .onDisappear { heroShown = false }
                }
                // The card is its own surface: no row box around it.
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if !venue.photos.isEmpty {
                    Section {
                        VenueGallery(photos: venue.photos, serverURL: session.serverURL)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            Group {
                sections
            }
            .brandListRow()
        }
        // DEBUG only (`PLAYERZ_VENUE_AT=courts`): the picker on top, for a screenshot.
        .task(id: model.courts.count) {
            if let at = DebugLaunch.venueAt, !model.courts.isEmpty { proxy.scrollTo(at, anchor: .top) }
        }
        }
    }

    @ViewBuilder
    private var sections: some View {
        // «Обект на …», to the club's page, as on the web (#17).
        if let slug = model.venue?.clubSlug, let name = model.clubName {
            Section {
                NavigationLink(String(localized: "venue.club \(name)")) {
                    ClubView(slug: slug, session: session)
                }
            }
        }

        if let banner = model.banner {
            Section {
                Text(banner)
                    // Colour alone must not carry the meaning — the words
                    // already say which outcome it is.
                    .foregroundStyle(model.bannerIsError ? Theme.Palette.danger : Theme.Palette.success)
            }
        }

        if model.showsAnyForecast {
            Section { WeatherAttribution() }
        }

        // A court is chosen on a drawing first; the times below are that
        // court's only (owner 2026-11-13). The club's plan (#25) where it has
        // one, time first; otherwise the courts drawn side by side.
        if let plan = model.plan {
            VenuePlanSection(drawing: plan, courts: model.courts, busySlot: nil, book: book, picked: $selectedCourt)
        }
        let offPlan = model.courts.filter { court in !(model.plan?.courts.contains { $0.id == court.resourceId } ?? false) }
        if !offPlan.isEmpty, model.courts.count > 1 {
            Section {
                VenueCourtPicker(courts: offPlan, selected: $selectedCourt) { openedPlace = PlaceRoute(id: $0) }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .listRowBackground(Color.clear)
            } header: {
                // «Избери корт», «Избери игрище», «Избери място» for a mix.
                let word = PlaceWord.common(offPlan.map(\.sport))
                Text(model.plan == nil
                    ? String(localized: "venue.places.choose \(PlaceText.lower(word))")
                    : String(localized: "venue.places.others \(PlaceText.plural(word))"))
            }
            .id("courts")
        }

        // Inline only where nothing is picked on a picker: a venue with one
        // place, or a place chosen on the plan. A picker's place opens its
        // own screen (PlaceHoursView).
        let inline = model.courts.filter { court in
            court.resourceId == selectedCourt
                && (model.courts.count == 1 || !offPlan.contains { $0.resourceId == court.resourceId })
        }
        ForEach(inline, id: \.resourceId) { court in
            Section {
                if court.bookable.isEmpty {
                    Text(String(localized: "venue.noSlots"))
                        .foregroundStyle(.secondary)
                }
                // Hours are picked here and reserved together from the
                // summary (owner 2026-11-13), on the grid (the design draft).
                if !court.hours.isEmpty {
                    HourGrid(
                        court: court, timezone: model.timezone,
                        isPicked: { model.isPicked(court, $0) },
                        toggle: { model.toggle(court, $0) }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } header: {
                CourtHeader(court: court, forecast: model.forecast(for: court))
            }
        }

        if !coaches.isEmpty {
            VenueCoachesSection(coaches: coaches, venueId: venueId, session: session)
        }
    }

    /// The places of the club's grid, in its order: what a place's screen swipes through.
    private var pickerOrder: [String] {
        model.courts
            .filter { court in !(model.plan?.courts.contains { $0.id == court.resourceId } ?? false) }
            .map(\.resourceId)
    }

    private func offerPushIfUndecided() {
        Task {
            if await !PushRegistrar.shared.alreadyDecided() { offerPush = true }
        }
    }

    /// A court booked from the plan (#25), as a slot is from the list.
    private func book(_ court: VenueDetailModel.Court, _ slot: Components.Schemas.AvailabilitySlot) {
        // Picked, as from the list: the summary reserves them together.
        model.toggle(court, slot)
    }

    private func loadCoaches() async {
        guard session.modules.coaches, let client = await session.client() else { return }
        coaches = (try? await client.listVenueCoaches(path: .init(id: venueId)).ok.body.json.data.items) ?? []
    }

    private func writeToClub(_ slug: String) async {
        switch await ConversationOpener.open(session, .case2(.init(club: slug))) {
        case .success(let id): conversation = OpenedConversation(id: id)
        case .failure(let failure):
            writeProblem = failure.text
            showingWriteProblem = true
        }
    }

    private func loadFavourite() async {
        guard let client = await session.client(),
              let ids = try? await client.listMyFavouriteVenues().ok.body.json.data.ids
        else { return }
        favourite = ids.contains(venueId)
    }

    /// Shown at once, put back if the server says no.
    private func toggleFavourite() async {
        guard let was = favourite, let client = await session.client() else { return }
        favourite = !was
        let saved = was
            ? (try? await client.removeFavouriteVenue(path: .init(venueId: venueId)).ok) != nil
            : (try? await client.addFavouriteVenue(path: .init(venueId: venueId)).ok) != nil
        if !saved { favourite = was }
    }
}

/// The top of a venue's screen: its cover (the club's photo, or the drawn
/// band), then what the server says of it. Only what `GET /venues/{id}`
/// carries: no opening hours line (free-form JSON) and no amenities.
private struct VenueHero: View {
    let venue: Components.Schemas.VenueDetail
    let serverURL: String

    var body: some View {
        BrandCoverCard(coverHeight: 170, coverLabel: venue.cover?.alt) {
            VenueCover(photo: venue.cover, seed: venue.id, serverURL: serverURL, pixelWidth: 1280, sport: venue.sports.first)
        } logo: {
            VenueLogoTile(name: venue.name)
        } content: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(venue.name)
                    .font(Theme.Typography.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(.secondary)
                VenueCardTags(
                    price: venue.fromPriceCents.map { VenueFacts.price(fromCents: $0, currency: venue.currency) },
                    rating: rating,
                    sports: venue.sports
                )
                .padding(.top, Theme.Spacing.xs)
                if let description = venue.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }

    private var rating: (shown: String, spoken: String)? {
        VenueFacts.rating(venue.avgRating, count: venue.reviewCount)
    }

    private var place: String {
        [venue.addressLine, CityText.shown(venue.cityNames)].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Apple REQUIRES this wherever WeatherKit data appears.
///
/// Not a courtesy — it is in the terms, and it is an App Review item. The mark
/// and a link to Apple's legal attribution page must both be present, so this
/// renders only when a forecast is actually on screen: attribution for data
/// nobody is being shown would be noise.
private struct WeatherAttribution: View {
    private static let legal = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "weather.attribution"))
            Link(String(localized: "weather.legal"), destination: Self.legal)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

private struct CourtHeader: View {
    let court: VenueDetailModel.Court
    let forecast: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(court.name)
            Text(
                PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor)
            )
            .foregroundStyle(.secondary)

            // Outdoor courts only — an indoor court's weather is not a fact
            // anybody books on. #211.
            if let forecast {
                Spacer()
                Text(forecast).foregroundStyle(.secondary)
            }
        }
    }
}
