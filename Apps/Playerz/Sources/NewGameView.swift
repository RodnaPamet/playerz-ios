import PlayerzAPI
import SwiftUI

/// «Създай игра» in one flow (owner 2026-11-13: "I can't create a game
/// quickly"): the sport, a club, the hour, then the players wanted. It books
/// the court (paid at the club) and opens the game on the booking in one go.
/// Upcoming bookings come first, to look for players on one already made.
struct NewGameView: View {
    @Bindable var session: SessionModel

    @State private var sports: [String] = []
    @State private var sport: String?
    @State private var venues: [Components.Schemas.VenueSummary] = []
    @State private var loadingVenues = false
    @State private var mine: [Components.Schemas.MyBooking] = []
    /// DEBUG only (`PLAYERZ_NEWGAME`): the first club opened, for a screenshot.
    @State private var debugVenue: String?

    var body: some View {
        List {
            if !mine.isEmpty {
                Section {
                    ForEach(mine, id: \.id) { booking in
                        NavigationLink {
                            BookingGameView(bookingId: booking.id, session: session)
                        } label: {
                            // One line each: these are shortcuts, the new game is below.
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(GameText.day(booking.startTs, timezone: booking.venue.timezone)) · \(GameText.hours(booking.startTs, booking.endTs, timezone: booking.venue.timezone))")
                                    .font(Theme.Typography.rowTitle)
                                    .monospacedDigit()
                                Text("\(booking.venue.name) · \(booking.resource.name)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "newGame.mine"))
                } footer: {
                    Text(String(localized: "newGame.mine.footer"))
                }
                .brandListRow()
            }

            Section {
                ChipFlow {
                    ForEach(sports, id: \.self) { code in
                        BrandChip(GameText.sport(code), isSelected: sport == code) {
                            sport = code
                        }
                    }
                }
                // Clear of the section's rounded clip, which cut the first chip.
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, Theme.Spacing.xs)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                Text(String(localized: "newGame.sport"))
            }

            if let sport {
                Section {
                    SportBanner(sport: sport, title: GameText.sport(sport))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    SportStoryCard(sport: sport, session: session)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    if loadingVenues {
                        ProgressView(String(localized: "common.loading")).frame(maxWidth: .infinity)
                    } else if venues.isEmpty {
                        Text(String(localized: "newGame.noClubs")).foregroundStyle(.secondary)
                    }
                    ForEach(venues, id: \.id) { venue in
                        NavigationLink {
                            NewGameHoursView(session: session, venueId: venue.id, venueName: venue.name, sport: sport)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(venue.name).font(Theme.Typography.rowTitle)
                                Text(CityText.shown(venue.cityNames)).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "newGame.club"))
                }
                .brandListRow()
            }
        }
        .brandPage()
        .navigationTitle(String(localized: "newGame.title"))
        .brandHeader(.back(String(localized: "newGame.title")))
        .task { await load() }
        .task(id: sport) { await loadVenues() }
        .navigationDestination(item: $debugVenue) { id in
            if let sport, let venue = venues.first(where: { $0.id == id }) {
                NewGameHoursView(session: session, venueId: venue.id, venueName: venue.name, sport: sport)
            }
        }
    }

    private func load() async {
        guard let client = await session.client() else { return }
        if let facets = await VenueFacetChoices.load(client) {
            sports = facets.sports
            if sport == nil { sport = DebugLaunch.sport ?? facets.sports.first }
        }
        // The caller's own upcoming bookings that can look for players.
        if let page = try? await client.listMyBookings(.init(query: .init(when: .upcoming))).ok.body.json.data {
            mine = page.items
                .filter { $0.viewerRole == .BOOKER && $0.status == "CONFIRMED" && $0.lesson == nil && $0.tournamentMatch == nil }
                .prefix(2)
                .map { $0 }
        }
    }

    private func loadVenues() async {
        guard let sport, let client = await session.client() else { return }
        loadingVenues = true
        defer { loadingVenues = false }
        let page = try? await client.listVenues(query: .init(sport: sport, limit: 50)).ok.body.json.data
        venues = (page?.items ?? []).filter { $0.fromPriceCents != nil }
        if DebugLaunch.newGame != nil, debugVenue == nil { debugVenue = venues.first?.id }
    }
}

/// The hour: the club's places for the sport, each with its hours on the
/// grid; hours one after another on one place make the booking.
struct NewGameHoursView: View {
    @Bindable var session: SessionModel
    let venueId: String
    let venueName: String
    let sport: String

    @State private var model = VenueDetailModel()
    @State private var debugDetails = false

    /// The sport's places, each with only the hours a game can still open
    /// on: later than the club's cutoff. An hour inside it can be booked, but
    /// its game would take no requests (found on the local server).
    private var courts: [VenueDetailModel.Court] {
        let from = Date.now.addingTimeInterval(TimeInterval(cutoffHours * 3600))
        return model.courts.filter { $0.sport == sport }.map { court in
            VenueDetailModel.Court(
                resourceId: court.resourceId, name: court.name, sport: court.sport,
                currency: court.currency, isIndoor: court.isIndoor, maxMinutes: court.maxMinutes,
                bookable: court.bookable.filter { $0.startTs > from },
                hours: court.hours.filter { $0.startTs > from }
            )
        }
    }

    private var cutoffHours: Int { model.venue?.cancellationCutoffHours ?? 0 }
    private var oneBlock: Bool { model.blocks.count == 1 }

    var body: some View {
        List {
            if cutoffHours > 0 {
                Section {
                    Text(String(localized: "newGame.cutoff \(cutoffHours)"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .brandListRow()
            }
            ForEach(courts, id: \.resourceId) { court in
                Section {
                    if court.hours.isEmpty {
                        Text(String(localized: "venue.noSlots")).foregroundStyle(.secondary)
                    } else {
                        HourGrid(
                            court: court, timezone: model.timezone,
                            isPicked: { model.isPicked(court, $0) },
                            toggle: { model.toggle(court, $0) }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    SportBanner(
                        sport: court.sport,
                        title: court.name,
                        subtitle: PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor)
                    )
                    .textCase(nil)
                    .padding(.horizontal, -Theme.Spacing.l)
                }
            }
            if model.phase == .loading, courts.isEmpty {
                ProgressView(String(localized: "common.loading"))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.picks.isEmpty {
                VStack(spacing: Theme.Spacing.s) {
                    if !oneBlock {
                        Text(String(localized: "newGame.oneBlock"))
                            .font(.footnote)
                            .foregroundStyle(Theme.Palette.danger)
                    }
                    NavigationLink {
                        NewGameDetailsView(session: session, model: model, venueId: venueId, venueName: venueName, sport: sport)
                    } label: {
                        Text(String(localized: "newGame.next"))
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(!oneBlock)
                }
                .padding(Theme.Spacing.l)
                .background(Theme.Palette.page)
            }
        }
        .brandPage()
        .navigationTitle(venueName)
        .brandChipBar {
            if model.days.count > 1 {
                BrandChipRow {
                    ForEach(model.days) { day in
                        BrandChip(
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
        .brandHeader(.back(venueName))
        .task {
            await model.load(session, venueId: venueId)
            // On the first day with an hour a game can open on: inside the
            // cutoff, today often has none.
            for day in model.days.dropFirst().prefix(6) where !courts.contains(where: { !$0.bookable.isEmpty }) {
                await model.select(session, venueId: venueId, day: day)
            }
            // DEBUG only: hours picked and the players' step open, for a screenshot.
            if let count = DebugLaunch.pick, let court = courts.first(where: { !$0.bookable.isEmpty }) {
                for slot in court.bookable.prefix(count) { model.toggle(court, slot) }
                debugDetails = DebugLaunch.newGame == "details"
            }
        }
        .navigationDestination(isPresented: $debugDetails) {
            NewGameDetailsView(session: session, model: model, venueId: venueId, venueName: venueName, sport: sport)
        }
    }
}

/// The players wanted, then «Създай игра»: the booking, then the game on it.
struct NewGameDetailsView: View {
    @Bindable var session: SessionModel
    let model: VenueDetailModel
    let venueId: String
    let venueName: String
    let sport: String

    @State private var spots = 1
    @State private var levelMin: Int?
    @State private var levelMax: Int?
    @State private var note = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var created: String?

    private var block: HourlySlots.Block? { model.blocks.first }

    var body: some View {
        List {
            if let block, let pick = model.pick(for: block) {
                Section {
                    SportBanner(
                        sport: sport,
                        title: GameText.day(block.start, timezone: model.timezone),
                        subtitle: "\(GameText.hours(block.start, block.end, timezone: model.timezone)) · \(pick.placeName)"
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    LabeledContent(venueName, value: ReservationSheet.money(block.priceCents, pick.currency))
                    Text(String(localized: "reserve.payAtClub")).font(.footnote).foregroundStyle(.secondary)
                }
                .brandListRow()
            }
            if let problem {
                Section { Text(problem).foregroundStyle(Theme.Palette.danger) }
                    .brandListRow()
            }
            Section {
                Stepper(value: $spots, in: 1...7) {
                    Text(String(localized: "bookingGame.spots \(spots)"))
                }
                Picker(String(localized: "bookingGame.levelMin"), selection: $levelMin) {
                    Text(String(localized: "games.level.any")).tag(Int?.none)
                    ForEach(1...7, id: \.self) { Text("\($0)").tag(Optional($0)) }
                }
                Picker(String(localized: "bookingGame.levelMax"), selection: $levelMax) {
                    Text(String(localized: "games.level.any")).tag(Int?.none)
                    ForEach(1...7, id: \.self) { Text("\($0)").tag(Optional($0)) }
                }
                TextField(String(localized: "bookingGame.note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text(String(localized: "newGame.players"))
            }
            .brandListRow()
            Section {
                Button {
                    Task { await create() }
                } label: {
                    if busy { ProgressView() } else { Text(String(localized: "newGame.create")) }
                }
                .buttonStyle(.brandPrimary)
                .disabled(busy || block == nil || note.count > 280 || !levelsInOrder)
            }
            .bareListRow()
        }
        .brandPage()
        .navigationTitle(String(localized: "newGame.title"))
        .brandHeader(.back(String(localized: "newGame.title")))
        .navigationDestination(item: $created) { bookingId in
            BookingGameView(bookingId: bookingId, session: session)
        }
        .onChange(of: problem) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
        // DEBUG only (`PLAYERZ_RESERVE=1`, the local server): created at once.
        .task { if DebugLaunch.reserve, created == nil { spots = 2; await create() } }
    }

    private var levelsInOrder: Bool {
        guard let lo = levelMin, let hi = levelMax else { return true }
        return lo <= hi
    }

    /// The booking first; then the game on it, with no more players than the
    /// court holds (`maxSpots`, read back from the booking's game).
    private func create() async {
        busy = true
        problem = nil
        defer { busy = false }
        let outcomes = await model.reserve(session, venueId: venueId)
        guard let booking = outcomes.first?.booking else {
            problem = outcomes.first?.problem ?? String(localized: "newGame.failed")
            return
        }
        guard let client = await session.client(),
              let game = try? await client.getBookingGame(path: .init(id: booking.id)).ok.body.json.data,
              game.canOpen, game.maxSpots > 0
        else {
            problem = String(localized: "newGame.bookedNoGame")
            created = booking.id
            return
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let opened = try? await client.openBookingGame(
            path: .init(id: booking.id),
            body: .json(.init(
                spots: min(spots, game.maxSpots),
                levelMin: levelMin,
                levelMax: levelMax,
                note: trimmed.isEmpty ? nil : trimmed
            ))
        )
        if case .ok = opened {
            created = booking.id
        } else {
            problem = String(localized: "newGame.bookedNoGame")
            created = booking.id
        }
    }
}
