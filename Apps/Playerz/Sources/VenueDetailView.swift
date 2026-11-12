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
    @State private var showingBookings = false
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
        .brandPage()
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
                            day.label(timeZone: model.timezone, today: String(localized: "venue.today")),
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
        .brandHeader(.back(model.venue?.name ?? "")) {
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
            ConversationSheet(opened: opened, session: session)
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
            // concrete rather than on a cold launch.
            guard booked else { return }
            Task {
                if await !PushRegistrar.shared.alreadyDecided() { offerPush = true }
            }
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
        List {
            if let venue = model.venue {
                Section {
                    VenueHero(venue: venue, serverURL: session.serverURL)
                }
                // The card is its own surface: no row box around it.
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Group {
                sections
            }
            .brandListRow()
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
                    .foregroundStyle(model.bannerIsError ? .red : .green)
            }
        }

        if model.showsAnyForecast {
            Section { WeatherAttribution() }
        }

        // The plan (#25), where the venue has one: time first, then a court.
        if let plan = model.plan {
            VenuePlanSection(drawing: plan, courts: model.courts, busySlot: model.bookingSlot, book: book)
        }

        ForEach(model.courts, id: \.resourceId) { court in
            Section {
                if court.bookable.isEmpty {
                    Text(String(localized: "venue.noSlots"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(court.bookable, id: \.startTs) { slot in
                        SlotRow(
                            slot: slot,
                            currency: court.currency,
                            busy: model.bookingSlot == slot.startTs,
                            disabled: model.bookingSlot != nil
                        ) {
                            Task {
                                await model.book(
                                    session,
                                    venueId: venueId,
                                    resourceId: court.resourceId,
                                    slot: slot
                                )
                            }
                        }
                    }
                }
            } header: {
                CourtHeader(court: court, forecast: model.forecast(for: court))
            }
        }

        if !coaches.isEmpty {
            VenueCoachesSection(coaches: coaches, venueId: venueId, session: session)
        }
    }

    /// A court booked from the plan (#25), as a slot is from the list.
    private func book(_ court: VenueDetailModel.Court, _ slot: Components.Schemas.AvailabilitySlot) {
        Task { await model.book(session, venueId: venueId, resourceId: court.resourceId, slot: slot) }
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
}

/// The top of a venue's screen: its cover (the club's photo, or the drawn
/// band), then what the server says of it. Only what `GET /venues/{id}`
/// carries: no opening hours line (free-form JSON) and no amenities.
private struct VenueHero: View {
    let venue: Components.Schemas.VenueDetail
    let serverURL: String

    var body: some View {
        BrandCoverCard(coverHeight: 170) {
            VenueCover(photo: venue.cover, seed: venue.id, serverURL: serverURL, pixelWidth: 1280)
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
                ChipFlow {
                    if let cents = venue.fromPriceCents {
                        VenueFactChip(text: VenueFacts.price(fromCents: cents), prominent: true)
                    }
                    if let rating {
                        VenueFactChip(text: rating.shown, systemImage: "star.fill")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(rating.spoken)
                    }
                    ForEach(VenueFacts.sports(venue.sports), id: \.self) { sport in
                        VenueFactChip(text: sport)
                    }
                }
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
        [venue.addressLine, venue.city].filter { !$0.isEmpty }.joined(separator: ", ")
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
                court.isIndoor
                    ? String(localized: "venue.indoor")
                    : String(localized: "venue.outdoor")
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

private struct SlotRow: View {
    let slot: Components.Schemas.AvailabilitySlot
    let currency: String
    let busy: Bool
    let disabled: Bool
    let book: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the time, the price and the button cannot
        // share a line without truncating one of them.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())

        layout {
            Text(time)
            if !typeSize.isAccessibilitySize { Spacer() }
            Text(price).foregroundStyle(.secondary)

            Button(action: book) {
                if busy {
                    ProgressView()
                } else {
                    Text(String(localized: "venue.book"))
                }
            }
            .buttonStyle(.borderless)
            .disabled(disabled)
            // ═══ WITHOUT THIS, EVERY SLOT IS "Резервирай" ═══
            //
            // A court with twelve free hours renders twelve buttons with the
            // same label. VoiceOver reads the time as a SEPARATE element, so
            // nothing ties the two together and choosing an hour means
            // counting swipes.
            //
            // A ProgressView also has no label, so the busy state announced an
            // unlabelled button — the worst moment to lose the name.
            .accessibilityLabel(
                busy
                    ? String(localized: "venue.booking")
                    : String(format: String(localized: "a11y.bookSlot"), time, price)
            )
        }
    }

    private var time: String {
        slot.startTs.formatted(date: .omitted, time: .shortened)
    }

    private var price: String {
        (Decimal(slot.priceCents) / 100).formatted(.currency(code: currency))
    }
}
