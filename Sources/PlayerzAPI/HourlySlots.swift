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
    public static func hourly(_ slots: [Slot], timezone: TimeZone, now: Date = .now) -> [Slot] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return slots.compactMap { slot in
            guard slot.available, slot.startTs > now,
                  calendar.component(.minute, from: slot.startTs) == 0
            else { return nil }
            let durations = slot.durations ?? []
            let pick = durations.first { $0.minutes == 60 } ?? durations.min { $0.minutes < $1.minutes }
            return Slot(
                startTs: slot.startTs,
                endTs: pick?.endTs ?? slot.endTs,
                priceCents: pick?.priceCents ?? slot.priceCents,
                available: true,
                blockedReason: nil,
                durations: slot.durations
            )
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
