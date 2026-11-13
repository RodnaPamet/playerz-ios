import Foundation

/// Booking by the hour, several at once (owner 2026-11-13: «make the slots
/// per hour, not half hour, and selectable first, then reserved, so that you
/// can reserve more than one»).
public enum HourlySlots {
    public typealias Slot = Components.Schemas.AvailabilitySlot

    /// The free slots that start on the hour, each made one hour long: its
    /// 60-minute duration, or the shortest the place allows where that is
    /// longer (a 90-minute padel minimum stays 90). Not one that has begun:
    /// the server lists today's current hour as free, and refuses to book it
    /// (SLOT_NOT_BOOKABLE).
    ///
    /// `includeTaken` keeps the hours that are not free too, marked so
    /// (`available` false), for a grid that shows them as taken (the design
    /// draft: "label unavailable times").
    public static func hourly(
        _ slots: [Slot], timezone: TimeZone, now: Date = .now, includeTaken: Bool = false
    ) -> [Slot] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return slots.compactMap { slot in
            guard slot.available || includeTaken, slot.startTs > now,
                  calendar.component(.minute, from: slot.startTs) == 0
            else { return nil }
            let durations = slot.durations ?? []
            let pick = durations.first { $0.minutes == 60 } ?? durations.min { $0.minutes < $1.minutes }
            return Slot(
                startTs: slot.startTs,
                endTs: pick?.endTs ?? slot.endTs,
                priceCents: pick?.priceCents ?? slot.priceCents,
                available: slot.available,
                blockedReason: slot.blockedReason,
                durations: slot.durations
            )
        }
    }

    /// The part of the day an hour starts in, for the hours grid's groups.
    public enum Daypart: String, CaseIterable, Sendable {
        /// Before 12:00.
        case morning
        /// 12:00 to 17:00.
        case afternoon
        /// From 17:00.
        case evening
    }

    /// The hours in the parts of the day they start in, in order; a part
    /// with no hour is left out.
    public static func dayparts(_ slots: [Slot], timezone: TimeZone) -> [(part: Daypart, slots: [Slot])] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let grouped = Dictionary(grouping: slots) { slot -> Daypart in
            switch calendar.component(.hour, from: slot.startTs) {
            case ..<12: .morning
            case ..<17: .afternoon
            default: .evening
            }
        }
        return Daypart.allCases.compactMap { part in
            grouped[part].map { (part, $0.sorted { $0.startTs < $1.startTs }) }
        }
    }

    /// The picks that a fresh read shows are no longer free: on a place
    /// read, starting within the hours read, and not among its free hours.
    /// Picks on other days or places are not known to be gone.
    public static func gone(
        _ picks: [Pick], read: [String: [Slot]], free: [String: [Slot]]
    ) -> [Pick] {
        picks.filter { pick in
            guard let all = read[pick.resourceId], let first = all.map(\.startTs).min(),
                  let last = all.map(\.startTs).max(),
                  pick.start >= first, pick.start <= last
            else { return false }
            return !(free[pick.resourceId] ?? []).contains { $0.startTs == pick.start }
        }
    }

    /// An hour picked on a place.
    public struct Pick: Hashable, Sendable {
        public let resourceId: String
        public let start: Date
        public let end: Date
        public let priceCents: Int

        public init(resourceId: String, start: Date, end: Date, priceCents: Int) {
            self.resourceId = resourceId
            self.start = start
            self.end = end
            self.priceCents = priceCents
        }
    }

    /// One booking to make: hours back to back on one place, joined.
    public struct Block: Hashable, Sendable {
        public let resourceId: String
        public let start: Date
        public let end: Date
        public let priceCents: Int
        public let hours: Int
    }

    /// The picks as bookings: on each place, hours that follow each other are
    /// one booking (a club caps how many a player holds, 3 by default, so
    /// 18:00 and 19:00 must count as one), up to that place's longest
    /// booking; then the next. In order of place, then time.
    public static func blocks(_ picks: [Pick], maxMinutes: (String) -> Int?) -> [Block] {
        var out: [Block] = []
        let byPlace = Dictionary(grouping: picks, by: \.resourceId)
        for resourceId in byPlace.keys.sorted() {
            let longest = maxMinutes(resourceId).map { TimeInterval($0 * 60) } ?? .infinity
            var current: (start: Date, end: Date, price: Int, hours: Int)?
            for pick in byPlace[resourceId]!.sorted(by: { $0.start < $1.start }) {
                if let run = current, run.end == pick.start, pick.end.timeIntervalSince(run.start) <= longest {
                    current = (run.start, pick.end, run.price + pick.priceCents, run.hours + 1)
                } else {
                    if let run = current {
                        out.append(Block(resourceId: resourceId, start: run.start, end: run.end, priceCents: run.price, hours: run.hours))
                    }
                    current = (pick.start, pick.end, pick.priceCents, 1)
                }
            }
            if let run = current {
                out.append(Block(resourceId: resourceId, start: run.start, end: run.end, priceCents: run.price, hours: run.hours))
            }
        }
        return out
    }
}
