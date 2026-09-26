import Foundation
import Observation
import PlayerzAPI

@MainActor
@Observable
final class VenueDetailModel {
    enum Phase { case loading, loaded, failed }

    /// Availability joined to the detail response.
    ///
    /// `ResourceSlots` (availability) does NOT carry `isIndoor`; `VenueResource`
    /// (detail) does. Two calls, matched by id, because the weather line only
    /// applies to outdoor courts and availability alone cannot say which those
    /// are.
    struct Court {
        let resourceId: String
        let name: String
        let currency: String
        let isIndoor: Bool
        let bookable: [Components.Schemas.AvailabilitySlot]
    }

    private(set) var phase: Phase = .loading
    private(set) var venue: Components.Schemas.VenueDetail?
    private(set) var courts: [Court] = []
    private(set) var banner: String?
    private(set) var bannerIsError = false
    private(set) var bookingSlot: Date?
    /// Flips true once a booking is confirmed, so the view can offer push.
    private(set) var lastBookingSucceeded = false

    /// The strip of selectable days, and which one is showing. Both are
    /// computed in the VENUE's timezone — see VenueDay.
    private(set) var days: [VenueDay] = []
    private(set) var selectedDate: String?
    private(set) var timezone: String = "Europe/Sofia"

    private let weather = ForecastLine()
    private var forecasts: [String: String] = [:]

    /// One idempotency key per booking ATTEMPT, held per slot.
    ///
    /// ═══ WHY IT IS KEYED BY SLOT AND NOT GENERATED PER REQUEST ═══
    ///
    /// The header is required, and the server's contract is that reusing a key
    /// returns the booking it first created "whatever this request's body
    /// says". Both halves of that matter:
    ///
    ///   - a NEW key per tap means a retry after a network stall creates a
    ///     SECOND booking, which is the exact double-charge the header exists
    ///     to prevent — the first request may well have succeeded and lost its
    ///     response;
    ///   - a SHARED key across slots means tapping a different time returns the
    ///     first booking instead, silently, and the user gets an hour they did
    ///     not choose.
    ///
    /// So: stable per (court, start), fresh for anything else. A conflict
    /// creates no booking, so retrying that same slot later under the same key
    /// is safe.
    private var idempotencyKeys: [String: String] = [:]

    private func idempotencyKey(resourceId: String, startTs: Date) -> String {
        let slot = "\(resourceId)@\(startTs.timeIntervalSince1970)"
        if let existing = idempotencyKeys[slot] { return existing }
        let fresh = UUID().uuidString
        idempotencyKeys[slot] = fresh
        return fresh
    }

    func forecast(for court: Court) -> String? {
        court.isIndoor ? nil : forecasts[court.resourceId]
    }

    func select(_ session: SessionModel, venueId: String, day: VenueDay) async {
        guard day.apiDate != selectedDate else { return }
        selectedDate = day.apiDate
        await load(session, venueId: venueId)
    }

    func load(_ session: SessionModel, venueId: String) async {
        phase = .loading
        guard let client = await session.client() else {
            phase = .failed
            return
        }

        do {
            let detail = try await client
                .getVenue(.init(path: .init(id: venueId)))
                .ok.body.json.data
            let availability = try await client
                .getVenueAvailability(
                    .init(path: .init(id: venueId), query: .init(date: selectedDate))
                )
                .ok.body.json.data

            let indoorById = Dictionary(
                uniqueKeysWithValues: detail.resources.map { ($0.id, $0.isIndoor) }
            )

            venue = detail
            // The venue's own zone decides what "today" is and what the strip
            // offers — not the device's.
            timezone = availability.timezone
            if days.isEmpty {
                days = VenueDay.upcoming(inTimeZone: availability.timezone)
                selectedDate = days.first?.apiDate
            }
            courts = availability.resources.map { slots in
                Court(
                    resourceId: slots.resourceId,
                    name: slots.name,
                    currency: slots.currency,
                    // Absent from the detail response means we do not know, and
                    // "unknown" must not render a forecast as if it were an
                    // outdoor court. Defaulting to indoor suppresses the line.
                    isIndoor: indoorById[slots.resourceId] ?? true,
                    bookable: slots.slots.filter(\.available)
                )
            }
            phase = .loaded

            await loadForecasts(lat: detail.lat, lng: detail.lng)
        } catch {
            phase = .failed
        }
    }

    /// One fetch per outdoor court's first bookable slot.
    private func loadForecasts(lat: Double, lng: Double) async {
        for court in courts where !court.isIndoor {
            guard let first = court.bookable.first else { continue }
            await weather.load(lat: lat, lng: lng, at: first.startTs)
            if let summary = weather.summary {
                forecasts[court.resourceId] = summary
            }
        }
    }

    func book(
        _ session: SessionModel,
        venueId: String,
        resourceId: String,
        slot: Components.Schemas.AvailabilitySlot
    ) async {
        guard let client = await session.client(), let slug = venue?.slug else { return }

        bookingSlot = slot.startTs
        banner = nil
        defer { bookingSlot = nil }

        do {
            let response = try await client.createBooking(
                .init(
                    path: .init(slug: slug),
                    headers: .init(
                        Idempotency_hyphen_Key: idempotencyKey(
                            resourceId: resourceId,
                            startTs: slot.startTs
                        )
                    ),
                    body: .json(
                        .init(resourceId: resourceId, startTs: slot.startTs, endTs: slot.endTs)
                    )
                )
            )

            switch response {
            case .ok, .created:
                bannerIsError = false
                banner = String(localized: "venue.booked")
                lastBookingSucceeded = true
                // Re-read rather than mutating locally: the slot that was just
                // taken is not the only thing that changed if somebody else
                // booked an overlapping one in the meantime.
                await load(session, venueId: venueId)
            case .conflict:
                bannerIsError = true
                banner = String(localized: "venue.slotTaken")
                await load(session, venueId: venueId)
            default:
                bannerIsError = true
                banner = String(localized: "venue.bookFailed")
            }
        } catch {
            bannerIsError = true
            banner = String(localized: "venue.bookFailed")
        }
    }
}
