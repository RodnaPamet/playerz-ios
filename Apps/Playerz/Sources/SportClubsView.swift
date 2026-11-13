import PlayerzAPI
import SwiftUI

/// A sport's page (owner 2026-11-13: "guide in the reverse way to booking a
/// venue - sport card contains club pages, swipable"): the sport in its
/// photo, then the clubs that offer it, one page a swipe; each page the
/// club's places for that sport and their hours, picked and reserved as on
/// the club's own page.
struct SportClubsView: View {
    let sport: String
    @Bindable var session: SessionModel

    @State private var clubs: [Components.Schemas.VenueSummary] = []
    @State private var phase: Phase = .loading
    @State private var current: String?

    enum Phase { case loading, loaded, failed }

    var body: some View {
        VStack(spacing: 0) {
            SportBanner(sport: sport, title: GameText.sport(sport), subtitle: subtitle)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
            switch phase {
            case .loading:
                ProgressView(String(localized: "common.loading")).frame(maxHeight: .infinity)
            case .failed:
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "venues.failed")) {
                    Button(String(localized: "venues.retry")) { Task { await load() } }
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            case .loaded where clubs.isEmpty:
                BrandEmptyState(systemImage: "sportscourt", title: String(localized: "newGame.noClubs"))
            case .loaded:
                if clubs.count > 1 { dots }
                TabView(selection: $current) {
                    ForEach(clubs, id: \.id) { club in
                        SportClubPage(club: club, sport: sport, session: session)
                            .tag(Optional(club.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .brandPage()
        .navigationTitle(GameText.sport(sport))
        .brandHeader(.back(GameText.sport(sport)))
        .task { await load() }
    }

    /// «3 клуба», or the sport's places while the clubs load.
    private var subtitle: String {
        clubs.isEmpty
            ? PlaceText.plural(PlaceWord.of(sport)).capitalized
            : String(localized: "sports.clubCount \(clubs.count)")
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(clubs.prefix(12), id: \.id) { club in
                Circle()
                    .fill(club.id == (current ?? clubs.first?.id) ? Theme.Palette.accentText : Theme.Palette.hairline)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.top, Theme.Spacing.s)
        .accessibilityHidden(true)
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        guard let page = try? await client.listVenues(query: .init(sport: sport, limit: 50)).ok.body.json.data else {
            phase = .failed
            return
        }
        // Bookable only: a club with no price has no place to book.
        clubs = page.items.filter { $0.fromPriceCents != nil }
        current = clubs.first?.id
        phase = .loaded
    }
}

/// One club on a sport's page: its name, the days, and its places for the
/// sport with their hours; the picks bar and the summary as on its own page.
private struct SportClubPage: View {
    let club: Components.Schemas.VenueSummary
    let sport: String
    let session: SessionModel

    @State private var model = VenueDetailModel()
    @State private var reviewing = false

    private var courts: [VenueDetailModel.Court] { model.courts.filter { $0.sport == sport } }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    VenueDetailView(venueId: club.id, session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(club.name).font(Theme.Typography.cardTitle)
                        Text(CityText.shown(club.cityNames)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if model.days.count > 1 {
                    BrandChipRow {
                        ForEach(model.days) { day in
                            BrandChip(
                                GameText.filterDay(day, zone: model.timezone),
                                isSelected: day.apiDate == model.selectedDate
                            ) {
                                Task { await model.select(session, venueId: club.id, day: day) }
                            }
                        }
                    }
                    .padding(.horizontal, -Theme.Spacing.l)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "venue.dayPicker"))
                    .listRowBackground(Color.clear)
                }
            }
            .brandListRow()

            ForEach(courts, id: \.resourceId) { court in
                Section {
                    if court.bookable.isEmpty {
                        Text(String(localized: "venue.noSlots")).foregroundStyle(.secondary)
                    }
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
                    HStack(spacing: 6) {
                        Text(court.name)
                        Text(PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor)).foregroundStyle(.secondary)
                    }
                }
                .brandListRow()
            }
            if model.phase == .loading, courts.isEmpty {
                ProgressView(String(localized: "common.loading"))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
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
        .sheet(isPresented: $reviewing) {
            ReservationSheet(model: model, session: session, venueId: club.id, venueName: club.name)
                .outsideShellBar()
        }
        .task { await model.load(session, venueId: club.id) }
    }
}
