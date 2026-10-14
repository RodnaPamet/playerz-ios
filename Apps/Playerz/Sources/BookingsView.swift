import PlayerzAPI
import SwiftUI

struct BookingsView: View {
    let slug: String
    @Bindable var session: SessionModel
    @State private var model = BookingsModel()
    @State private var pendingCancel: Components.Schemas.Booking?

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView(String(localized: "common.loading"))
            case .failed:
                ContentUnavailableView {
                    Text(String(localized: "bookings.failed"))
                } actions: {
                    Button(String(localized: "venues.retry")) {
                        Task { await model.load(session, slug: slug) }
                    }
                }
            case .loaded where model.bookings.isEmpty:
                ContentUnavailableView(String(localized: "bookings.empty"), systemImage: "calendar")
            case .loaded:
                List {
                    if let banner = model.banner {
                        Section { Text(banner).foregroundStyle(model.bannerIsError ? .red : .primary) }
                    }
                    // A section per booking, one action per row: several links in
                    // one cell share its tap.
                    ForEach(model.bookings, id: \.id) { booking in
                        Section {
                            BookingRow(
                            booking: booking,
                            session: session,
                            busy: model.cancelling == booking.id,
                            disabled: model.cancelling != nil
                        ) { pendingCancel = booking }
                        }
                    }
                }
                .refreshable { await model.load(session, slug: slug) }
            }
        }
        .navigationTitle(String(localized: "bookings.title"))
        .navigationBarTitleDisplayMode(.inline)

        .task { await model.load(session, slug: slug) }
        .onChange(of: model.banner) { _, banner in
            guard let banner else { return }
            // Especially here: the refund line is the whole point of the
            // action, and a banner mid-list is silent to VoiceOver.
            AccessibilityNotification.Announcement(banner).post()
        }
        .confirmationDialog(
            String(localized: "bookings.confirmTitle"),
            isPresented: .init(get: { pendingCancel != nil }, set: { if !$0 { pendingCancel = nil } }),
            titleVisibility: .visible
        ) {
            // Destructive and irreversible: cancelling twice is a 409, not a
            // no-op, because each call writes a fresh receipt and recomputes
            // the refund from the CURRENT hours-until-start.
            Button(String(localized: "bookings.cancel"), role: .destructive) {
                if let booking = pendingCancel {
                    Task { await model.cancel(session, slug: slug, booking: booking) }
                }
                pendingCancel = nil
            }
            Button(String(localized: "bookings.confirmKeep"), role: .cancel) { pendingCancel = nil }
        }
    }
}

private struct BookingRow: View {
    let booking: Components.Schemas.Booking
    let session: SessionModel
    let busy: Bool
    let disabled: Bool
    let cancel: () -> Void

    // Separate rows in the booking's section, not one VStack: a cell's links
    // and buttons would share its tap.
    @ViewBuilder var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(when).font(.headline)
            HStack {
                Text(BookingCancel.status(booking.status)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(amount).font(.subheadline)
            }
        }
        // The description is one element; the button stays its own, so it
        // is still reachable and actionable.
        .accessibilityElement(children: .combine)

        if booking.status != "CANCELLED" {
            Button(role: .destructive, action: cancel) {
                if busy {
                    ProgressView()
                } else {
                    Text(String(localized: "bookings.cancel"))
                }
            }
            .buttonStyle(.borderless)
            .disabled(disabled)
            // Several bookings mean several identical "Откажи" buttons, and
            // this one is destructive and not undoable — cancelling twice
            // is a 409, and the refund is recomputed from the CURRENT
            // hours-until-start. Naming the booking is the difference
            // between confirming and guessing.
            .accessibilityLabel(
                busy
                    ? String(localized: "bookings.cancelling")
                    : String(format: String(localized: "a11y.cancelBooking"), when)
            )
        }

        // Who is playing, with «Пиши» to each of them (#484).
        if booking.status != "CANCELLED" {
            NavigationLink {
                BookingPlayersView(bookingId: booking.id, session: session)
            } label: {
                Text(String(localized: "bookingPlayers.title"))
            }
        }

        // Open play (#510): the booker looks for players for a booking to come.
        if booking.status == "CONFIRMED", booking.startTs > .now {
            // Destination-style, as the rest of this stack (Играй) is: the
            // two kinds of link do not mix well in one hierarchy.
            NavigationLink {
                BookingGameView(bookingId: booking.id, session: session)
            } label: {
                Text(String(localized: "bookingGame.link"))
            }
            .accessibilityLabel(String(localized: "a11y.bookingGame \(when)"))
        }
    }

    private var when: String {
        booking.startTs.formatted(date: .abbreviated, time: .shortened)
    }

    private var amount: String {
        (Decimal(booking.totalCents) / 100).formatted(.currency(code: booking.currency))
    }
}

@MainActor
@Observable
final class BookingsModel {
    enum Phase { case loading, loaded, failed }

    private(set) var phase: Phase = .loading
    private(set) var bookings: [Components.Schemas.Booking] = []
    private(set) var banner: String?
    private(set) var bannerIsError = false
    private(set) var cancelling: String?

    func load(_ session: SessionModel, slug: String) async {
        phase = .loading
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            bookings = try await client
                .listBookings(.init(path: .init(slug: slug)))
                .ok.body.json.data.items
            phase = .loaded
        } catch {
            phase = .failed
        }
    }

    func cancel(_ session: SessionModel, slug: String, booking: Components.Schemas.Booking) async {
        cancelling = booking.id
        banner = nil
        defer { cancelling = nil }
        let outcome = await BookingCancel.run(session, clubSlug: slug, bookingId: booking.id, currency: booking.currency)
        banner = outcome.text
        bannerIsError = outcome.isError
        await load(session, slug: slug)
    }
}
