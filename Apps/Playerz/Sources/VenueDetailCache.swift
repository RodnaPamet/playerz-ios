import Foundation
import PlayerzAPI

/// What a club's page reads first, kept for a minute and read ahead (owner
/// 2026-11-13: "it takes too long for a club to load ... needs to be
/// instant"). The list reads each card's club and today's hours as the card
/// comes on screen; the page opens on them at once and refreshes behind.
@MainActor
final class VenueDetailCache {
    static let shared = VenueDetailCache()

    struct Entry<Value> {
        let value: Value
        let at: Date
    }

    /// How long a read stands in for a fresh one; the page refreshes behind it either way.
    static let fresh: TimeInterval = 60

    private var details: [String: Entry<Components.Schemas.VenueDetail>] = [:]
    private var availability: [String: Entry<Components.Schemas.VenueAvailability>] = [:]
    private var inFlight: Set<String> = []

    func detail(_ venueId: String) -> Components.Schemas.VenueDetail? {
        details[venueId].flatMap { Date.now.timeIntervalSince($0.at) < Self.fresh ? $0.value : nil }
    }

    func availability(_ venueId: String, date: String?) -> Components.Schemas.VenueAvailability? {
        availability[Self.key(venueId, date)].flatMap { Date.now.timeIntervalSince($0.at) < Self.fresh ? $0.value : nil }
    }

    func store(_ detail: Components.Schemas.VenueDetail) {
        details[detail.id] = Entry(value: detail, at: .now)
    }

    func store(_ read: Components.Schemas.VenueAvailability, venueId: String, date: String?) {
        availability[Self.key(venueId, date)] = Entry(value: read, at: .now)
    }

    /// Hours just booked here: the kept read would show them free.
    func forget(_ venueId: String) {
        availability = availability.filter { !$0.key.hasPrefix("\(venueId)|") }
    }

    /// The club and today's hours, both at once, unless a fresh read is kept.
    func prefetch(_ session: SessionModel, venueId: String) async {
        let today = VenueDay.upcoming(inTimeZone: "Europe/Sofia").first?.apiDate
        guard detail(venueId) == nil || availability(venueId, date: today) == nil,
              !inFlight.contains(venueId), let client = await session.client()
        else { return }
        inFlight.insert(venueId)
        defer { inFlight.remove(venueId) }
        async let detail = try? client.getVenue(.init(path: .init(id: venueId))).ok.body.json.data
        async let hours = try? client.getVenueAvailability(.init(path: .init(id: venueId), query: .init(date: today))).ok.body.json.data
        if let detail = await detail { store(detail) }
        if let hours = await hours { store(hours, venueId: venueId, date: today) }
    }

    private static func key(_ venueId: String, _ date: String?) -> String { "\(venueId)|\(date ?? "")" }
}
