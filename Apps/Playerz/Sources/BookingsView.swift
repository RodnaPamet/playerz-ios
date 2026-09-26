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
                    ForEach(model.bookings, id: \.id) { booking in
                        BookingRow(
                            booking: booking,
                            busy: model.cancelling == booking.id,
                            disabled: model.cancelling != nil
                        ) { pendingCancel = booking }
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
    let busy: Bool
    let disabled: Bool
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                Text(when).font(.headline)
                HStack {
                    Text(booking.status).font(.caption).foregroundStyle(.secondary)
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
        guard let client = await session.client() else { return }

        cancelling = booking.id
        banner = nil
        defer { cancelling = nil }

        do {
            // The body is optional and a body-less POST is the common case.
            let response = try await client.cancelBooking(
                .init(path: .init(slug: slug, id: booking.id))
            )

            switch response {
            case let .ok(ok):
                let quote = try ok.body.json.data
                bannerIsError = false
                banner = refundLine(quote, currency: booking.currency)
            case .conflict:
                // Already cancelled. Each call writes a fresh receipt, so the
                // server refuses rather than silently agreeing — and the list
                // is out of date, hence the reload below.
                bannerIsError = true
                banner = String(localized: "bookings.already")
            case .notFound:
                // Someone else's booking answers 404, never 403 — a 403 would
                // confirm it exists and let a club's reservations be enumerated
                // one id at a time. Nothing to distinguish here on purpose.
                bannerIsError = true
                banner = String(localized: "bookings.cancelFailed")
            default:
                bannerIsError = true
                banner = String(localized: "bookings.cancelFailed")
            }
        } catch {
            bannerIsError = true
            banner = String(localized: "bookings.cancelFailed")
        }

        await load(session, slug: slug)
    }

    /// ═══ "DUE", NEVER "REFUNDED" ═══
    ///
    /// The endpoint cancels the booking and writes a Cancellation receipt with
    /// the resolved percentage frozen onto it. It does NOT move money — issuing
    /// the Stripe refund is a separate operation — and the spec instructs
    /// clients in as many words not to say "refunded", only "refund of X due".
    ///
    /// Telling someone their money is back when it is not is the kind of copy
    /// that turns a cancellation into a support ticket and a chargeback.
    private func refundLine(_ quote: Components.Schemas.CancelQuote, currency: String) -> String {
        guard quote.refundAmountCents > 0 else {
            return String(localized: "bookings.noRefund")
        }
        let amount = (Decimal(quote.refundAmountCents) / 100)
            .formatted(.currency(code: currency))
        return String(format: String(localized: "bookings.refundDue"), amount)
    }
}
