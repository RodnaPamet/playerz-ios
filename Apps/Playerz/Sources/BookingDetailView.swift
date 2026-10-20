import PlayerzAPI
import SwiftUI

/// One of the caller's bookings (playerz-ios#14), the web's `/me/bookings/{id}`:
/// when and where, with directions; the price, paid at the club; the players;
/// cancelling it; and, once it is played, the venue's review.
struct BookingDetailView: View {
    let bookingId: String
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var booking: Components.Schemas.MyBookingDetail?
    @State private var result: Components.Schemas.BookingResultState?
    @State private var debugEditor = false
    @State private var failed = false
    @State private var confirmingCancel = false
    @State private var cancelling = false
    @State private var cancelLine: (text: String, isError: Bool)?

    var body: some View {
        Group {
            if let booking {
                ScrollViewReader { proxy in
                    List {
                        BookingDetailSummary(booking: booking)
                        BookingDetailPlace(booking: booking, session: session)
                        if booking.status != "CANCELLED" {
                            Section {
                                NavigationLink {
                                    BookingPlayersView(bookingId: booking.id, session: session)
                                } label: {
                                    LabeledContent(String(localized: "myBookings.detail.players"), value: "\(booking.players.count)")
                                }
                                if session.modules.openPlay, booking.status == "CONFIRMED", booking.endTs > .now {
                                    NavigationLink(String(localized: "bookingGame.link")) {
                                        BookingGameView(bookingId: booking.id, session: session)
                                    }
                                }
                            }
                        }
                        BookingResultSection(
                            bookingId: booking.id,
                            timezone: booking.venue.timezone,
                            standing: $result,
                            session: session
                        )
                        .id(BookingResultSection.anchor)
                        BookingDetailReview(booking: booking, session: session, reviewed: reload)
                        if let cancelLine {
                            Section {
                                Text(cancelLine.text).foregroundStyle(cancelLine.isError ? .red : .secondary)
                            }
                        }
                        if canCancel(booking) {
                            Section {
                                Button(String(localized: "myBookings.detail.cancel"), role: .destructive, action: askToCancel)
                                    .disabled(cancelling)
                                    .confirmationDialog(
                                        String(localized: "myBookings.detail.confirm.title"),
                                        isPresented: $confirmingCancel,
                                        titleVisibility: .visible
                                    ) {
                                        Button(String(localized: "myBookings.detail.confirm.yes"), role: .destructive, action: cancel)
                                    }
                            } footer: {
                                if let until = booking.cancellableUntil {
                                    Text(String(localized: "myBookings.detail.cancelUntil \(GameText.when(until, timezone: booking.venue.timezone))"))
                                }
                            }
                        } else if cutoffPassed(booking) {
                            BookingCutoffPassed(booking: booking)
                        }
                    }
                    .refreshable { await load() }
                    .task(id: result?.canReport) {
                        // A DEBUG launch can look at the result (DebugLaunch).
                        guard result != nil, DebugLaunch.result != nil else { return }
                        try? await Task.sleep(for: .milliseconds(400))
                        proxy.scrollTo(BookingResultSection.anchor, anchor: .top)
                        if DebugLaunch.result == "editor", result?.canReport == true { debugEditor = true }
                    }
                }
                .navigationDestination(isPresented: $debugEditor) {
                    if let result {
                        ResultEditorView(bookingId: bookingId, standing: result, session: session) { self.result = $0 }
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "bookings.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: reload)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(booking?.venue.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// Cancelled under the club's slug; without one there is nothing to cancel under.
    private func canCancel(_ booking: Components.Schemas.MyBookingDetail) -> Bool {
        booking.viewerRole == .BOOKER && booking.clubSlug != nil
            && (booking.cancellableUntil.map { $0 > .now } ?? false)
    }

    /// Still ahead, but past the club's cutoff: only the club can cancel now.
    private func cutoffPassed(_ booking: Components.Schemas.MyBookingDetail) -> Bool {
        booking.viewerRole == .BOOKER && booking.startTs > .now
            && (booking.cancellableUntil.map { $0 <= .now } ?? false)
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        switch try? await client.getMyBooking(path: .init(id: bookingId)) {
        case let .ok(ok)?:
            if let found = try? ok.body.json.data {
                booking = found
                failed = false
                await loadResult(found)
            } else {
                failed = booking == nil
            }
        case .notFound?:
            // No longer the caller's: they left it, or the booker removed them.
            dismiss()
        default:
            failed = booking == nil
        }
    }

    /// The result, once the booking is over (#18): only then can it have one.
    private func loadResult(_ booking: Components.Schemas.MyBookingDetail) async {
        guard session.modules.ranking, booking.endTs < .now, let client = await session.client() else { return }
        if let fresh = try? await client.getBookingResult(path: .init(id: booking.id)).ok.body.json.data {
            result = fresh
        }
    }

    private func askToCancel() {
        confirmingCancel = true
    }

    private func cancel() {
        guard let booking, let clubSlug = booking.clubSlug else { return }
        cancelling = true
        Task {
            defer { cancelling = false }
            cancelLine = await BookingCancel.run(
                session,
                clubSlug: clubSlug,
                bookingId: booking.id,
                currency: booking.currency
            )
            await load()
        }
    }
}
