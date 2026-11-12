import PlayerzAPI
import SwiftUI

/// Резервации (projectZ#167): the caller's bookings at every club, as the
/// web's tab has them (#359): «Предстоящи», soonest first, and «Минали»,
/// newest first. Bookings the caller was added to are here too (#358).
struct MyBookingsView: View {
    @Bindable var session: SessionModel

    @State private var when: Operations.listMyBookings.Input.Query.whenPayload = .upcoming
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
            List {
                if let banner {
                    Section { Text(banner.text).foregroundStyle(banner.isError ? .red : .primary) }
                        .brandListRow()
                }
                // A section per booking, one action per row: several links in
                // one cell share its tap.
                ForEach(items, id: \.id) { booking in
                    Section { row(booking) }
                        .brandListRow()
                        .onAppear {
                            if booking.id == items.last?.id { Task { await loadMore() } }
                        }
                }
            }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private func row(_ booking: Components.Schemas.MyBooking) -> some View {
        let upcoming = when == .upcoming
        // Cancelled under the club's slug; without one there is nothing to cancel under.
        let canCancel = booking.clubSlug != nil && (booking.cancellableUntil.map { $0 > .now } ?? false)
        // The booking in full (#14): where, the players, the review.
        NavigationLink {
            BookingDetailView(bookingId: booking.id, session: session)
        } label: {
            MyBookingSummary(booking: booking)
        }

        if session.modules.openPlay, upcoming, booking.status == "CONFIRMED" {
            NavigationLink(String(localized: "bookingGame.link")) {
                BookingGameView(bookingId: booking.id, session: session)
            }
        }
        if canCancel && booking.viewerRole == .BOOKER {
            Button(role: .destructive) {
                pendingCancel = booking
                confirmingCancel = true
            } label: {
                if cancelling == booking.id { ProgressView() } else { Text(String(localized: "bookings.cancel")) }
            }
            .buttonStyle(.borderless)
            .disabled(cancelling != nil)
        }
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
