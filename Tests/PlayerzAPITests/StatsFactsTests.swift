import Foundation
import Testing

@testable import PlayerzAPI

@Suite("StatsFacts")
struct StatsFactsTests {
    @Test("a whole percent, none of nothing")
    func percent() {
        #expect(StatsFacts.percent(16, of: 27) == 59)
        #expect(StatsFacts.percent(1, of: 3) == 33)
        #expect(StatsFacts.percent(2, of: 3) == 67)
        #expect(StatsFacts.percent(0, of: 0) == nil)
    }

    @Test("the busiest index, the first on a tie, none when nothing was played")
    func busiest() {
        #expect(StatsFacts.busiest([0, 2, 5, 5, 1, 0, 0]) == 2)
        #expect(StatsFacts.busiest([0, 0, 0]) == nil)
        #expect(StatsFacts.busiest([]) == nil)
    }

    @Test("the two hours played most, over midnight too")
    func twoHours() {
        var hours = Array(repeating: 0, count: 24)
        hours[18] = 3
        hours[19] = 2
        hours[9] = 4
        #expect(StatsFacts.busiestTwoHours(hours) == 18)
        var late = Array(repeating: 0, count: 24)
        late[23] = 2
        late[0] = 2
        #expect(StatsFacts.busiestTwoHours(late) == 23)
        #expect(StatsFacts.busiestTwoHours(Array(repeating: 0, count: 24)) == nil)
        #expect(StatsFacts.busiestTwoHours([1, 2]) == nil)
    }

    @Test("a level's change to two decimals, none without both sides")
    func change() {
        #expect(StatsFacts.change(from: 4.0, to: 4.126) == 0.13)
        #expect(StatsFacts.change(from: 4.2, to: 4.05) == -0.15)
        #expect(StatsFacts.change(from: nil, to: 4) == nil)
        #expect(StatsFacts.change(from: 4, to: nil) == nil)
    }

    @Test("a chart's levels: padded, whole, inside 1–7, never flat")
    func levelDomain() {
        #expect(StatsFacts.levelDomain([3.6, 3.8]) == 3...5)
        #expect(StatsFacts.levelDomain([4.0]) == 3...5)
        #expect(StatsFacts.levelDomain([1.1, 6.9]) == 1...7)
        #expect(StatsFacts.levelDomain([6.8]) == 6...7)
        #expect(StatsFacts.levelDomain([]) == 1...7)
    }
}
