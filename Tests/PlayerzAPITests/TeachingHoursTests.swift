import Testing

@testable import PlayerzAPI

@Suite("A coach's weekly hours")
struct TeachingHoursTests {
    @Test("clock strings, both ways", arguments: [("9:00", 540), ("21:30", 1290), ("0:00", 0), ("24:00", 1440), ("08:15", 495)])
    func clock(_ text: String, _ minutes: Int) {
        #expect(TeachingHours.minutes(text) == minutes)
    }

    @Test("written as the server writes them")
    func written() {
        #expect(TeachingHours.clock(540) == "9:00")
        #expect(TeachingHours.clock(1290) == "21:30")
        #expect(TeachingHours.clock(495) == "8:15")
    }

    @Test("not a time", arguments: ["9", "9:5", "25:00", "9:60", "ab:cd", "24:15"])
    func notATime(_ text: String) {
        #expect(TeachingHours.minutes(text) == nil)
    }

    @Test("a day's stretches")
    func stretches() {
        #expect(TeachingHours.valid([(540, 720), (840, 1080)]))
        #expect(TeachingHours.valid([]))
        #expect(!TeachingHours.valid([(540, 720), (700, 800)]))
        #expect(!TeachingHours.valid([(545, 720)]))
        #expect(!TeachingHours.valid([(720, 540)]))
        #expect(!TeachingHours.valid(Array(repeating: (540, 555), count: 5)))
    }
}
