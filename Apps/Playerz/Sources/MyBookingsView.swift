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
                .navigationTitle(String(localized: "myBookings.title"))
                // Inline: with a segmented control inset below the bar, iOS 26 hid the large
                // title under the bar's material.
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top) {
                    Picker(String(localized: "myBookings.when"), selection: $when) {
                        Text(String(localized: "myBookings.upcoming"))
                            .tag(Operations.listMyBookings.Input.Query.whenPayload.upcoming)
                        Text(String(localized: "myBookings.past"))
                            .tag(Operations.listMyBookings.Input.Query.whenPayload.past)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .background(.bar)
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
            ContentUnavailableView {
                Text(String(localized: "bookings.failed"))
            } actions: {
                Button(String(localized: "venues.retry")) { Task { await load() } }
            }
        case .loaded where items.isEmpty:
            ContentUnavailableView(
                when == .upcoming
                    ? String(localized: "myBookings.emptyUpcoming")
                    : String(localized: "myBookings.emptyPast"),
                systemImage: "calendar"
            )
        case .loaded:
            List {
                if let banner {
                    Section { Text(banner.text).foregroundStyle(banner.isError ? .red : .primary) }
                }
                // A section per booking, one action per row: several links in
                // one cell share its tap.
                ForEach(items, id: \.id) { booking in
                    Section { row(booking) }
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
