import Testing

@testable import PlayerzAPI

@Suite("Entering a result")
struct ResultDraftTests {
    @Test("the first half starts on side 1, the rest on side 2")
    func firstSeats() {
        let draft = ResultDraft(players: ["a", "b", "c"], format: .periods)
        #expect(draft.seats == ["a": .side(0), "b": .side(0), "c": .side(1)])
        #expect(draft.rows.count == 2)
        #expect(ResultDraft(players: ["a", "b"], format: .total).rows.count == 1)
    }

    @Test("a draw's sides are kept, and a player not in them is out")
    func fixedSides() {
        let draft = ResultDraft(players: ["a", "b", "c"], format: .periods, fixedSides: [["c"], ["a"]])
        #expect(draft.fixedSides)
        #expect(draft.seats == ["a": .side(1), "b": .out, "c": .side(0)])
    }

    @Test("a singles result in two sets")
    func singles() throws {
        var draft = ResultDraft(players: ["a", "b"], format: .periods)
        draft.rows = [["6", "4"], [" 7", "5 "]]
        let sent = try draft.request()
        #expect(sent.sides == [["a"], ["b"]])
        #expect(sent.score == [[6, 4], [7, 5]])
    }

    @Test("a player who did not play is left out")
    func out() throws {
        var draft = ResultDraft(players: ["a", "b", "c"], format: .total)
        draft.seats["b"] = .out
        draft.rows = [["3", "1"]]
        #expect(try draft.request().sides == [["a"], ["c"]])
    }

    @Test("an empty side is refused")
    func emptySide() {
        var draft = ResultDraft(players: ["a", "b"], format: .total)
        draft.seats["b"] = .side(0)
        draft.rows = [["3", "1"]]
        #expect(throws: ResultDraft.Problem.sides) { try draft.request() }
    }

    @Test("a box that is not a number is refused", arguments: ["", "x", "-1", "1000", "٣", "6.5"])
    func notANumber(_ typed: String) {
        var draft = ResultDraft(players: ["a", "b"], format: .total)
        draft.rows = [[typed, "1"]]
        #expect(throws: ResultDraft.Problem.score) { try draft.request() }
    }

    @Test("one to five sets")
    func sets() {
        var draft = ResultDraft(players: ["a", "b"], format: .periods)
        for _ in 0..<10 { draft.addSet() }
        #expect(draft.rows.count == ResultDraft.maxSets)
        for _ in 0..<10 { draft.removeSet() }
        #expect(draft.rows.count == 1)
        var total = ResultDraft(players: ["a", "b"], format: .total)
        total.addSet()
        #expect(total.rows.count == 1)
    }
}
