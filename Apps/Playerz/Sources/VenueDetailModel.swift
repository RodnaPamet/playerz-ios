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
        /// For the court's drawing in the picker (owner 2026-11-13).
        let sport: String
        let currency: String
        let isIndoor: Bool
        /// Its longest booking, so hours back to back join up to it.
        let maxMinutes: Int
        /// The free hours: on the hour, an hour long (owner 2026-11-13).
        let bookable: [Components.Schemas.AvailabilitySlot]
    }

    /// An hour picked for the summary (owner 2026-11-13: selectable first,
    /// then reserved, more than one at a time).
    struct Pick: Hashable, Identifiable {
        let resourceId: String
        let placeName: String
        let sport: String
        let currency: String
        let start: Date
        let end: Date
        let priceCents: Int
        var id: String { "\(resourceId)@\(start.timeIntervalSince1970)" }
    }

    /// What became of one booking the summary asked for.
    struct Outcome: Identifiable {
        let block: HourlySlots.Block
        let placeName: String
        let sport: String
        let currency: String
        /// The booking made, or nil.
        let booking: Components.Schemas.Booking?
        /// Why not, in the user's words.
        let problem: String?
        var id: String { "\(block.resourceId)@\(block.start.timeIntervalSince1970)" }
    }

    /// The hours picked, kept across days and places until reserved or cleared.
    private(set) var picks: [Pick] = []
    /// While a summary is up: the push offer waits (its alert would close it).
    var summaryOpen = false

    private(set) var phase: Phase = .loading
    private(set) var venue: Components.Schemas.VenueDetail?
    /// The club's name, for «Обект на …» linking to its page (#17); nil until read.
    private(set) var clubName: String?
    private(set) var courts: [Court] = []
    /// The venue's plan (#25): nil until read, or while no court is on it.
    private(set) var plan: VenuePlanDrawing?
    /// Read once per screen: the plan does not change with the day.
    private var planRead = false
    private(set) var banner: String?
    private(set) var bannerIsError = false
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

    /// Whether any forecast is actually on screen.
    ///
    /// Drives the attribution row: Apple requires it wherever WeatherKit data
    /// appears, and only there. An all-indoor club shows no forecast and
    /// therefore needs no attribution — and a fetch that failed shows none
    /// either, so the row would be crediting data nobody received.
    var showsAnyForecast: Bool {
        courts.contains { !$0.isIndoor && forecasts[$0.resourceId] != nil }
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

        // «Днес» before the first read: asked without a date, the server
        // answers the next 24 hours, and tomorrow morning's hours showed under
        // «Днес» (owner's TestFlight, 2026-11-13). Sofia until the venue's own
        // zone is known; corrected below if it differs.
        if days.isEmpty {
            days = VenueDay.upcoming(inTimeZone: timezone)
            selectedDate = days.first?.apiDate
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
            let sportById = Dictionary(uniqueKeysWithValues: detail.resources.map { ($0.id, $0.sport) })

            venue = detail
            // The club's name, for the link to its page (#17). Public, and the
            // screen works without it.
            if clubName == nil,
                let club = try? await client.getClub(.init(path: .init(slug: detail.clubSlug))).ok.body.json.data
            {
                clubName = club.name
            }
            // The venue's own zone decides what "today" is and what the strip
            // offers — not the device's.
            if availability.timezone != timezone {
                timezone = availability.timezone
                days = VenueDay.upcoming(inTimeZone: availability.timezone)
                selectedDate = days.first?.apiDate
            }
            courts = availability.resources.map { slots in
                Court(
                    resourceId: slots.resourceId,
                    name: slots.name,
                    sport: sportById[slots.resourceId] ?? "",
                    currency: slots.currency,
                    // Absent from the detail response means we do not know, and
                    // "unknown" must not render a forecast as if it were an
                    // outdoor court. Defaulting to indoor suppresses the line.
                    isIndoor: indoorById[slots.resourceId] ?? true,
                    maxMinutes: slots.maxBookingMinutes,
                    bookable: HourlySlots.hourly(
                        slots.slots,
                        timezone: TimeZone(identifier: availability.timezone) ?? .current
                    )
                )
            }
            phase = .loaded

            await loadPlan(client, venueId: venueId)
            await loadForecasts(lat: detail.lat, lng: detail.lng)
        } catch {
            phase = .failed
        }
    }

    /// The plan, once. A failed read leaves the list alone and is tried again
    /// with the next day.
    private func loadPlan(_ client: Client, venueId: String) async {
        guard !planRead,
              let read = try? await client.getVenuePlan(path: .init(id: venueId)).ok.body.json.data
        else { return }
        planRead = true
        plan = VenuePlanDrawing(read)
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

    // MARK: - Picking hours, then reserving them

    func isPicked(_ court: Court, _ slot: Components.Schemas.AvailabilitySlot) -> Bool {
        picks.contains { $0.resourceId == court.resourceId && $0.start == slot.startTs }
    }

    /// Picks the hour, or puts it back.
    func toggle(_ court: Court, _ slot: Components.Schemas.AvailabilitySlot) {
        if let index = picks.firstIndex(where: { $0.resourceId == court.resourceId && $0.start == slot.startTs }) {
            picks.remove(at: index)
        } else {
            picks.append(Pick(
                resourceId: court.resourceId, placeName: court.name, sport: court.sport,
                currency: court.currency, start: slot.startTs, end: slot.endTs, priceCents: slot.priceCents
            ))
            picks.sort { ($0.start, $0.placeName) < ($1.start, $1.placeName) }
        }
    }

    func clearPicks() { picks = [] }

    var picksTotalCents: Int { picks.reduce(0) { $0 + $1.priceCents } }

    /// The bookings the picks make: hours back to back on a place joined.
    var blocks: [HourlySlots.Block] {
        let longest = Dictionary(uniqueKeysWithValues: courts.map { ($0.resourceId, $0.maxMinutes) })
        return HourlySlots.blocks(
            picks.map { .init(resourceId: $0.resourceId, start: $0.start, end: $0.end, priceCents: $0.priceCents) },
            maxMinutes: { longest[$0] }
        )
        .sorted { $0.start < $1.start }
    }

    /// The pick that names a block's place.
    func pick(for block: HourlySlots.Block) -> Pick? {
        picks.first { $0.resourceId == block.resourceId }
    }

    /// Books every block, one after another, and says what became of each.
    /// The hours that were booked leave the picks; the rest stay, to try again.
    func reserve(_ session: SessionModel, venueId: String) async -> [Outcome] {
        guard let client = await session.client(), let slug = venue?.clubSlug else { return [] }
        session.send(.sheetOpened, venueId: venueId)
        var outcomes: [Outcome] = []
        for block in blocks {
            let named = pick(for: block)
            let made = await create(client, session: session, slug: slug, block: block)
            outcomes.append(Outcome(
                block: block, placeName: named?.placeName ?? "", sport: named?.sport ?? "",
                currency: named?.currency ?? "EUR", booking: made.booking, problem: made.problem
            ))
            if made.booking != nil {
                picks.removeAll { $0.resourceId == block.resourceId && $0.start >= block.start && $0.start < block.end }
                lastBookingSucceeded = true
            }
        }
        await load(session, venueId: venueId)
        return outcomes
    }

    private func create(
        _ client: Client, session: SessionModel, slug: String, block: HourlySlots.Block
    ) async -> (booking: Components.Schemas.Booking?, problem: String?) {
        let response: Operations.createBooking.Output
        do {
            response = try await client.createBooking(
                .init(
                    path: .init(slug: slug),
                    // One key per block (place, start, end): a retry of the
                    // same block replays its booking; another block gets its own.
                    headers: .init(Idempotency_hyphen_Key: idempotencyKey(
                        resourceId: "\(block.resourceId)~\(block.end.timeIntervalSince1970)", startTs: block.start
                    )),
                    body: .json(.init(resourceId: block.resourceId, startTs: block.start, endTs: block.end))
                )
            )
        } catch {
            return (nil, String(localized: "venue.bookFailed"))
        }
        switch response {
        case let .ok(ok): return ((try? ok.body.json.data), nil)
        case let .created(created): return ((try? created.body.json.data), nil)
        case .conflict:
            let error = apiError(response)
            if error?.code == "BOOKING_LIMIT_REACHED", let limit = apiErrorDetail(error, "limit") {
                return (nil, String(localized: "reserve.limit \(limit)"))
            }
            return (nil, String(localized: "venue.slotTaken"))
        default:
            let code = apiErrorCode(response)
            session.notice(refusal: code)
            if code == "SLOT_NOT_BOOKABLE" { return (nil, String(localized: "reserve.notBookable")) }
            return (nil, code == "PHONE_REQUIRED"
                ? String(localized: "phone.required.title")
                // Three no-shows block online booking at the club; the server
                // says so in the player's own language, with whom to call.
                : code == "NO_SHOW_BLOCKED"
                    ? (apiError(response)?.message ?? String(localized: "venue.bookFailed"))
                    : String(localized: "venue.bookFailed"))
        }
    }
}
