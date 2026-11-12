import PlayerzAPI
import SwiftUI

struct VenueListView: View {
    @Bindable var session: SessionModel
    @State private var model = VenueListModel()
    @State private var debugClub: String? = DebugLaunch.club
    @State private var debugVenue: String? = DebugLaunch.venue
    /// «Треньори» on show: from the header's pill, «Създай», or a DEBUG launch.
    @State private var showingCoaches = DebugLaunch.coaches
    /// Changed to start the stack again from the club list.
    @State private var stackID = 0
    @State private var debugCoach: String? = DebugLaunch.coach
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loading:
                    ProgressView(String(localized: "common.loading"))
                case .failed:
                    BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "venues.failed")) {
                        Button(String(localized: "venues.retry")) {
                            Task { await model.load(session) }
                        }
                        .buttonStyle(.brandSecondary(fullWidth: false))
                    }
                case .locating:
                    ProgressView(String(localized: "venues.locating"))
                case .locationDenied:
                    BrandEmptyState(
                        systemImage: "location.slash",
                        title: String(localized: "venues.nearMe"),
                        message: String(localized: "venues.noLocation")
                    )
                case .loaded where model.rows.isEmpty:
                    BrandEmptyState(
                        systemImage: "figure.tennis",
                        title: model.mode == .near
                            ? String(localized: "venues.noneNearby")
                            : String(localized: "venues.empty")
                    )
                case .loaded:
                    // Cards on the page, not rows in one box: each club is its own.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.Spacing.l) {
                            shortcuts
                            Text(String(localized: "venues.title"))
                                .font(Theme.Typography.sectionTitle)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(model.rows) { row in
                                NavigationLink {
                                    VenueDetailView(venueId: row.id, session: session)
                                } label: {
                                    VenueCard(row: row)
                                }
                                .buttonStyle(.brandCard)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.l)
                    }
                    .refreshable { await model.load(session) }
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
            // Hidden with the system bar, but still what a pushed screen's back button says.
            .navigationTitle(String(localized: "venues.title"))
            .brandChipBar {
                BrandChipRow {
                    BrandChip(String(localized: "venues.all"), isSelected: model.mode == .all) { show(.all) }
                    BrandChip(String(localized: "venues.nearMe"), systemImage: "location", isSelected: model.mode == .near) {
                        show(.near)
                    }
                }
            }
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
        .task { await model.load(session) }
        // «Създай» asked for the club list or «Треньори»; `initial`, for a
        // request made before this tab was first opened.
        .onChange(of: session.homeRequest, initial: true) { _, request in
            guard let request else { return }
            session.homeRequest = nil
            debugClub = nil
            debugVenue = nil
            debugCoach = nil
            showingCoaches = request == .coaches && session.modules.coaches
            stackID += 1
        }
    }

    private func show(_ mode: VenueListModel.Mode) {
        Task { await model.setMode(mode, session: session) }
    }

    /// The two things to do besides booking a court here, each while its
    /// module is on (#16). Side by side, or one under the other at the text
    /// sizes where two would squeeze their titles.
    @ViewBuilder private var shortcuts: some View {
        if session.modules.openPlay || session.modules.coaches {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Theme.Spacing.m))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.m))
            layout {
                if session.modules.openPlay {
                    Button {
                        session.requestedTab = .games
                    } label: {
                        BrandActionCard(
                            title: String(localized: "home.games.title"),
                            subtitle: String(localized: "home.games.subtitle"),
                            systemImage: "person.3",
                            style: .accent,
                            minHeight: 140,
                            fillsHeight: true
                        )
                    }
                    .buttonStyle(.brandCard)
                }
                if session.modules.coaches {
                    Button {
                        showingCoaches = true
                    } label: {
                        BrandActionCard(
                            title: String(localized: "create.lesson.title"),
                            subtitle: String(localized: "create.lesson.subtitle"),
                            systemImage: "figure.tennis",
                            minHeight: 140,
                            fillsHeight: true
                        )
                    }
                    .buttonStyle(.brandCard)
                }
            }
            // As tall as the taller one, so the pair reads as one row.
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One club: a tile with its initial (no club has a picture yet), its name,
/// where it is, and the price as a chip.
private struct VenueCard: View {
    let row: VenueListModel.Row

    /// Grows with the name beside it.
    @ScaledMetric(relativeTo: .title3) private var tileSide: CGFloat = 60

    var body: some View {
        BrandContentCard {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Text(verbatim: row.name.first.map { String($0).uppercased() } ?? "")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.Palette.onHeader)
                    .frame(width: tileSide, height: tileSide)
                    .background(
                        LinearGradient(
                            colors: [Theme.Palette.headerInk, Theme.Palette.headerGlow],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: .rect(cornerRadius: Theme.Radius.tile)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(row.name)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Color.primary)

                    // A separate "·" Text is read as its own fragment by VoiceOver and
                    // wraps badly at large sizes. One string instead.
                    Text(placeLine)
                        .font(Theme.Typography.cardSubtitle)
                        .foregroundStyle(.secondary)

                    if let line = priceLine {
                        Text(line)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, Theme.Spacing.s)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Palette.chipIdle, in: .capsule)
                            .padding(.top, 2)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        // One utterance per club. Left alone, VoiceOver reads three fragments
        // and the NavigationLink's own label on top of them.
        .accessibilityElement(children: .combine)
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
        let money = Decimal(cents) / 100
        let formatted = money.formatted(.currency(code: "EUR").locale(Locale(identifier: "bg_BG")))
        return String(format: String(localized: "venues.fromPrice"), formatted)
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
    }

    private(set) var phase: Phase = .loading
    private(set) var rows: [Row] = []
    private(set) var mode: Mode = .all

    private let location = LocationProvider()

    func setMode(_ mode: Mode, session: SessionModel) async {
        guard mode != self.mode || rows.isEmpty else { return }
        self.mode = mode
        await load(session)
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }

        do {
            switch mode {
            case .all:
                phase = .loading
                // Discovery is public — BearerMiddleware exempts it, so this
                // works signed out and does not widen what a browse correlates
                // with.
                let items = try await client.listVenues(.init()).ok.body.json.data.items
                rows = items.map {
                    Row(
                        id: $0.id, name: $0.name, city: $0.city, country: $0.country,
                        fromPriceCents: $0.fromPriceCents, distanceKm: nil
                    )
                }

            case .near:
                phase = .locating
                let here = try await location.current()

                phase = .loading
                let result = try await client.findVenuesNear(
                    .init(
                        query: .init(
                            lat: here.latitude,
                            lng: here.longitude,
                            // Named radiusKm, not radius, and silently clamped
                            // to 50 rather than rejected — so asking for more
                            // would quietly mean 50 anyway.
                            radiusKm: 50
                        )
                    )
                ).ok.body.json.data
                rows = result.venues.map {
                    Row(
                        id: $0.id, name: $0.name, city: $0.city, country: $0.country,
                        // /venues/near does not carry a price; the row omits it
                        // rather than showing a wrong one.
                        fromPriceCents: nil, distanceKm: $0.distanceKm
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
}
