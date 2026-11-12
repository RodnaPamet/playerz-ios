import PlayerzAPI
import SwiftUI

/// Резервации (projectZ#167): the caller's bookings at every club, as the
/// web's tab has them (#359): «Предстоящи», soonest first, and «Минали»,
/// newest first. Bookings the caller was added to are here too (#358).
struct MyBookingsView: View {
    @Bindable var session: SessionModel

    @State private var when: Operations.listMyBookings.Input.Query.whenPayload = DebugLaunch.bookingsPast ? .past : .upcoming
    @State private var items: [Components.Schemas.MyBooking] = []
    @State private var nextCursor: String?
    @State private var phase: Phase = .loading
    @State private var cancelling: String?
    @State private var pendingCancel: Components.Schemas.MyBooking?
    @State private var confirmingCancel = false
    @State private var banner: (text: String, isError: Bool)?
    /// A DEBUG launch can open a booking's game straight away (DebugLaunch).
    @State private var debugGame: String? = DebugLaunch.bookingGame
    /// …or the booking itself, or its players.
    @State private var debugBooking: String? = DebugLaunch.booking
    @State private var debugPlayers: String? = DebugLaunch.bookingPlayers

    enum Phase { case loading, loaded, failed }

    var body: some View {
        NavigationStack {
            content
                .brandPage()
                // Hidden with the system bar, but still what a pushed screen's back button says.
                .navigationTitle(String(localized: "myBookings.title"))
                .brandChipBar {
                    BrandChipRow {
                        BrandChip(String(localized: "myBookings.upcoming"), isSelected: when == .upcoming) { when = .upcoming }
                        BrandChip(String(localized: "myBookings.past"), isSelected: when == .past) { when = .past }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "myBookings.when"))
                }
                .brandHeader(.title(String(localized: "myBookings.title"))) {
                    BrandHeaderActions(session: session)
                }
                .navigationDestination(item: $debugGame) { id in
                    BookingGameView(bookingId: id, session: session)
                }
                .navigationDestination(item: $debugBooking) { id in
                    BookingDetailView(bookingId: id, session: session)
                }
                .navigationDestination(item: $debugPlayers) { id in
                    BookingPlayersView(bookingId: id, session: session)
                }
        }
        .task(id: when) { await load() }
        // Back on this tab: a court booked on another one is in the list.
        .onShellTabReturn { await load() }
        .onChange(of: banner?.text) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
        .confirmationDialog(
            String(localized: "bookings.confirmTitle"),
            isPresented: $confirmingCancel,
            titleVisibility: .visible,
            presenting: pendingCancel
        ) { booking in
            Button(String(localized: "bookings.cancel"), role: .destructive) {
                Task { await cancel(booking) }
            }
            Button(String(localized: "bookings.confirmKeep"), role: .cancel) {}
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "bookings.failed")) {
                Button(String(localized: "venues.retry")) { Task { await load() } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: "calendar",
                title: when == .upcoming
                    ? String(localized: "myBookings.emptyUpcoming")
                    : String(localized: "myBookings.emptyPast")
            )
        case .loaded:
            // Cards on the page: each booking is its own, with its own actions.
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.l) {
                    if let banner {
                        BrandContentCard {
                            Label(banner.text, systemImage: banner.isError ? "exclamationmark.triangle" : "checkmark.circle")
                                .foregroundStyle(banner.isError ? Theme.Palette.danger : Color.primary)
                        }
                    }
                    ForEach(items, id: \.id) { booking in
                        card(booking)
                            .onAppear {
                                if booking.id == items.last?.id { Task { await loadMore() } }
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await load() }
        }
    }

    /// One booking: the summary opens it in full (#14: where, the players,
    /// the review); under a hairline, what can be done with it from here.
    private func card(_ booking: Components.Schemas.MyBooking) -> some View {
        // Cancelled under the club's slug; without one there is nothing to cancel under.
        let canCancel = booking.clubSlug != nil
            && (booking.cancellableUntil.map { $0 > .now } ?? false)
            && booking.viewerRole == .BOOKER
        let canSeekPlayers = session.modules.openPlay && when == .upcoming && booking.status == "CONFIRMED"
        return VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                BookingDetailView(bookingId: booking.id, session: session)
            } label: {
                MyBookingSummary(booking: booking)
                    .padding(Theme.Spacing.l)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if canSeekPlayers || canCancel {
                Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
                // Side by side, or one under the other when the words are large.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.s) {
                        if canSeekPlayers { seekPlayers(booking) }
                        Spacer(minLength: Theme.Spacing.s)
                        if canCancel { cancelButton(booking) }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        if canSeekPlayers { seekPlayers(booking) }
                        if canCancel { cancelButton(booking) }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .brandCardSurface()
    }

    private func seekPlayers(_ booking: Components.Schemas.MyBooking) -> some View {
        NavigationLink {
            BookingGameView(bookingId: booking.id, session: session)
        } label: {
            Label(String(localized: "bookingGame.link"), systemImage: "person.badge.plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.accentText)
                .frame(minHeight: Theme.minTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func cancelButton(_ booking: Components.Schemas.MyBooking) -> some View {
        Button {
            pendingCancel = booking
            confirmingCancel = true
        } label: {
            Group {
                if cancelling == booking.id {
                    ProgressView().accessibilityLabel(String(localized: "bookings.cancelling"))
                } else {
                    Text(String(localized: "bookings.cancel"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(cancelling != nil)
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client.listMyBookings(.init(query: .init(when: when))).ok.body.json.data
            items = page.items
            nextCursor = page.nextCursor
            phase = .loaded
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        if let page = try? await client
            .listMyBookings(.init(query: .init(cursor: cursor, when: when)))
            .ok.body.json.data {
            let seen = Set(items.map(\.id))
            items += page.items.filter { !seen.contains($0.id) }
            nextCursor = page.nextCursor
        }
    }

    private func cancel(_ booking: Components.Schemas.MyBooking) async {
        guard let clubSlug = booking.clubSlug else { return }
        cancelling = booking.id
        defer { cancelling = nil }
        let outcome = await BookingCancel.run(
            session, clubSlug: clubSlug, bookingId: booking.id, currency: booking.currency
        )
        banner = outcome
        await load()
    }
}
