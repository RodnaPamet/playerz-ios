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
    /// A DEBUG launch can open the venue's review form (`PLAYERZ_OPEN=review`).
    @State private var debugReview = false
    @State private var failed = false
    @State private var confirmingCancel = false
    @State private var cancelling = false
    @State private var cancelLine: (text: String, isError: Bool)?

    var body: some View {
        Group {
            if let booking {
                ScrollViewReader { proxy in
                    List {
                        Group {
                            sections(booking)
                        }
                        .brandListRow()
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
                .navigationDestination(isPresented: $debugReview) {
                    if let clubSlug = booking.clubSlug {
                        VenueReviewForm(clubSlug: clubSlug, bookingId: booking.id, session: session, done: reload)
                    }
                }
                .navigationDestination(isPresented: $debugEditor) {
                    if let result {
                        ResultEditorView(bookingId: bookingId, standing: result, session: session) { self.result = $0 }
                    }
                }
            } else if failed {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "bookings.failed")) {
                    Button(String(localized: "venues.retry"), action: reload)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView()
            }
        }
        .brandPage()
        // The screen the assistant is told about (#122).
        .assistantPage(.booking(bookingId))
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(booking?.venue.name ?? "")
        .brandHeader(.back(booking?.venue.name ?? ""))
        .task { await load() }
    }

    @ViewBuilder private func sections(_ booking: Components.Schemas.MyBookingDetail) -> some View {
        BookingDetailSummary(booking: booking)
        // A tournament match (projectZ#685): the draw, where a proposed time is
        // answered and the other matches are.
        if let match = booking.tournamentMatch {
            Section {
                NavigationLink {
                    TournamentDrawView(
                        id: match.tournamentId, timezone: booking.venue.timezone,
                        venueId: booking.venue.id, session: session
                    )
                } label: {
                    Label(String(localized: "myBookings.match.draw \(match.tournamentName)"), systemImage: "trophy")
                }
            }
        }
        BookingDetailPlace(booking: booking, session: session)
        if booking.status != "CANCELLED" {
            Section {
                NavigationLink {
                    BookingPlayersView(bookingId: booking.id, session: session)
                } label: {
                    LabeledContent(String(localized: "myBookings.detail.players"), value: "\(booking.players.count)")
                }
                if session.modules.openPlay, booking.status == "CONFIRMED", booking.endTs > .now,
                   booking.tournamentMatch == nil {
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
        if session.modules.coaches, let lesson = booking.lesson {
            LessonCoachReview(bookingId: booking.id, lesson: lesson, session: session, reviewed: reload)
        }
        BookingDetailReview(booking: booking, session: session, reviewed: reload)
        if let cancelLine {
            Section {
                Text(cancelLine.text)
                    .foregroundStyle(cancelLine.isError ? Theme.Palette.danger : Color.secondary)
            }
        }
        if canCancel(booking) {
            Section {
                Button(String(localized: "myBookings.detail.cancel"), role: .destructive, action: askToCancel)
                    .foregroundStyle(Theme.Palette.danger)
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
                if DebugLaunch.open == "review", found.canReview, found.clubSlug != nil { debugReview = true }
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
