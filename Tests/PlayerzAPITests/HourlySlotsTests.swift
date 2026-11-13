import Foundation
import Testing

@testable import PlayerzAPI

@Suite("HourlySlots")
struct HourlySlotsTests {
    private let sofia = TimeZone(identifier: "Europe/Sofia")!
    /// 2026-11-14 18:00 in Sofia (UTC+2).
    private let six = Date(timeIntervalSince1970: 1_794_672_000)
    private func at(_ minutes: Int) -> Date { six.addingTimeInterval(TimeInterval(minutes * 60)) }

    private func slot(_ minutes: Int, durations: [Int], available: Bool = true) -> HourlySlots.Slot {
        .init(
            startTs: at(minutes),
            endTs: at(minutes + (durations.min() ?? 30)),
            priceCents: 1200,
            available: available,
            blockedReason: nil,
            durations: durations.map { .init(minutes: $0, endTs: at(minutes + $0), priceCents: $0 * 40) }
        )
    }

    @Test("on the hour only, an hour long, free only")
    func hourly() {
        let slots = [slot(0, durations: [60, 90]), slot(30, durations: [60]), slot(60, durations: [60], available: false), slot(120, durations: [60, 120])]
        let hours = HourlySlots.hourly(slots, timezone: sofia, now: at(-10))
        #expect(hours.map(\.startTs) == [at(0), at(120)])
        // An hour that has begun is not offered.
        #expect(HourlySlots.hourly(slots, timezone: sofia, now: at(5)).map(\.startTs) == [at(120)])
        #expect(hours.map(\.endTs) == [at(60), at(180)])
        #expect(hours.map(\.priceCents) == [2400, 2400])
    }

    @Test("a place whose shortest booking is longer than an hour keeps its shortest")
    func longerMinimum() {
        let hours = HourlySlots.hourly([slot(0, durations: [90, 120])], timezone: sofia, now: at(-10))
        #expect(hours.first?.endTs == at(90))
        #expect(hours.first?.priceCents == 3600)
    }

    @Test("hours back to back on one place are one booking, up to its longest")
    func blocks() {
        let pick = { (r: String, m: Int) in HourlySlots.Pick(resourceId: r, start: self.at(m), end: self.at(m + 60), priceCents: 2400) }
        let picks = [pick("a", 60), pick("a", 0), pick("a", 120), pick("a", 240), pick("b", 0)]
        let blocks = HourlySlots.blocks(picks) { $0 == "a" ? 120 : 180 }
        #expect(blocks.map(\.resourceId) == ["a", "a", "a", "b"])
        #expect(blocks.map(\.hours) == [2, 1, 1, 1])
        #expect(blocks[0].start == at(0) && blocks[0].end == at(120) && blocks[0].priceCents == 4800)
        #expect(blocks[1].start == at(120))
        #expect(blocks[2].start == at(240))
        #expect(HourlySlots.blocks([], maxMinutes: { _ in nil }).isEmpty)
    }
}
