import Foundation
import Testing

@testable import PlayerzAPI

/// The availability endpoint takes `date` as `YYYY-MM-DD` and states that it is
/// "interpreted in the VENUE's timezone (not UTC, and not the device's zone)".
///
/// Everything here is about honouring that sentence. The failure it prevents is
/// quiet: the request asks for a different day than the one on screen, the user
/// books a slot, and turns up twenty-four hours out.
@Suite("VenueDay")
struct VenueDayTests {
    /// 23:30 in London on 1 March is already 2 March in Sofia.
    private let lateInLondon = ISO8601DateFormatter().date(from: "2026-03-01T23:30:00Z")!

    @Test("today is the venue's today, not the device's")
    func usesVenueZone() {
        // The decisive case. At this instant a device in UTC says 1 March while
        // Sofia (UTC+2) says the 2nd. Formatting with the device's zone would
        // request the wrong day for every user west of the club — and for
        // everyone during the hours the two dates disagree.
        let days = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 3, now: lateInLondon)

        #expect(days.first?.apiDate == "2026-03-02")
        #expect(days.first?.isToday == true)
    }

    @Test("a venue in another zone gets its own dates")
    func perVenue() {
        // Same instant, different club: the answer must differ.
        let sofia = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 1, now: lateInLondon)
        let london = VenueDay.upcoming(inTimeZone: "Europe/London", count: 1, now: lateInLondon)

        #expect(sofia.first?.apiDate == "2026-03-02")
        #expect(london.first?.apiDate == "2026-03-01")
    }

    @Test("an unknown timezone uses the DECLARED fallback, not the device's zone")
    func unknownZoneUsesFallback() {
        // The first version of this compared an unknown zone against Sofia and
        // passed whether the code fell back to Sofia or to TimeZone.current —
        // because the machine it runs on IS Sofia. It even said so in a comment
        // and still could not tell the two apart.
        //
        // The zone has to DISAGREE with the machine's, or the assertion cannot
        // tell the two apart. My first attempt used Kiritimati (UTC+14), which
        // reads 2026-03-02 at this instant — and so does Sofia (UTC+2), the
        // zone this is developed in. The mutation passed.
        //
        // Honolulu is UTC-10, so it reads 2026-03-01 here: different from Sofia,
        // different from UTC+2 generally, and not a zone any machine running
        // this is plausibly set to.
        let days = VenueDay.upcoming(
            inTimeZone: "Mars/Olympus_Mons",
            count: 1,
            now: lateInLondon,
            fallback: "Pacific/Honolulu"
        )

        #expect(days.first?.apiDate == "2026-03-01")
        #expect(days.first?.apiDate != "2026-03-02", "that is Sofia — i.e. the fallback was ignored")
    }

    @Test("the default fallback is Sofia")
    func defaultFallbackIsSofia() {
        // Asserted as a literal rather than against TimeZone.current, so it
        // states what the default IS instead of agreeing with the machine.
        let days = VenueDay.upcoming(inTimeZone: "Mars/Olympus_Mons", count: 1, now: lateInLondon)
        #expect(days.first?.apiDate == "2026-03-02")
    }

    @Test("days advance by CALENDAR days across a DST change")
    func dstDoesNotSkipADay() {
        // Bulgaria springs forward on 29 March 2026. That day is 23 hours long,
        // so adding 86 400 seconds per step lands at 01:00 on the 30th and the
        // strip prints the 30th twice — or skips the 29th, depending on where
        // it starts. `byAdding: .day` is what makes this right.
        let beforeDST = ISO8601DateFormatter().date(from: "2026-03-27T10:00:00Z")!
        let days = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 5, now: beforeDST)

        #expect(days.map(\.apiDate) == ["2026-03-27", "2026-03-28", "2026-03-29", "2026-03-30", "2026-03-31"])
        #expect(Set(days.map(\.apiDate)).count == 5, "no day may repeat across the change")
    }

    @Test("and across an autumn change, where a day is 25 hours long")
    func autumnDSTAlsoHolds() {
        let beforeFallBack = ISO8601DateFormatter().date(from: "2026-10-23T10:00:00Z")!
        let days = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 4, now: beforeFallBack)

        #expect(days.map(\.apiDate) == ["2026-10-23", "2026-10-24", "2026-10-25", "2026-10-26"])
    }

    @Test("the strip never exceeds what the endpoint accepts")
    func clampedToFourteen() {
        // `days` on the endpoint must be 1..14; anything else is a 400. A strip
        // offering a fifteenth day offers a request that cannot succeed.
        #expect(VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 99).count == 14)
        #expect(VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 0).count == 1)
    }

    @Test("dates are Gregorian regardless of the device calendar")
    func fixedCalendar() {
        // A device set to the Buddhist calendar would otherwise format 2569,
        // which the server cannot parse.
        let days = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 1, now: lateInLondon)

        #expect(days.first?.apiDate.hasPrefix("2026-") == true)
        #expect(days.first?.apiDate.count == 10)
    }

    @Test("only the first day is today")
    func onlyOneToday() {
        let days = VenueDay.upcoming(inTimeZone: "Europe/Sofia", count: 5, now: lateInLondon)
        #expect(days.filter(\.isToday).count == 1)
        #expect(days.first?.isToday == true)
    }
}
