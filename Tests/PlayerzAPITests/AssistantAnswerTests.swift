import Foundation
import Testing

@testable import PlayerzAPI

/// The answer as blocks, and the drafts it carries.
@Suite("The assistant's answer")
struct AssistantAnswerTests {
    private let answer = """
    Ето свободните часове в събота за **падел**:

    | Клуб | Час |
    |---|---|
    | Падел Лозенец | 10:00 |
    | Арена Младост | 18:00 |

    Искаш ли да запазя някой?
    """

    @Test func aTableIsATableNotPipes() {
        let blocks = AssistantAnswer.blocks(answer)
        #expect(blocks.count == 3)
        #expect(blocks[0] == .paragraph("Ето свободните часове в събота за **падел**:"))
        #expect(blocks[1] == .table(header: ["Клуб", "Час"], rows: [["Падел Лозенец", "10:00"], ["Арена Младост", "18:00"]]))
    }

    @Test func theSpokenAnswerHasNoMarks() {
        let spoken = AssistantAnswer.spoken(answer)
        #expect(!spoken.contains("|"))
        #expect(!spoken.contains("**"))
        #expect(spoken.contains("Падел Лозенец, 10:00"))
    }

    @Test func listsHeadingsAndRules() {
        #expect(AssistantAnswer.blocks("## Утре\n- Корт 1\n* Корт 2\n1. Първо\n2) Второ\n---\nКрай.") == [
            .heading("Утре"), .bullets(["Корт 1", "Корт 2"]), .numbered(["Първо", "Второ"]), .divider, .paragraph("Край."),
        ])
        #expect(AssistantAnswer.blocks("2026. Годината беше добра.") == [.paragraph("2026. Годината беше добра.")],
                "a year is not a numbered list")
    }

    @Test func anUnevenTableStillReads() {
        #expect(AssistantAnswer.blocks("| А | Б | В |\n|---|:-:|---:|\n| 1 | 2 |\n| 3 | 4 | 5 | 6 |")
            == [.table(header: ["А", "Б", "В"], rows: [["1", "2", ""], ["3", "4", "5"]])])
    }

    @Test func linksAreKeptAsWords() {
        #expect(AssistantAnswer.plain("Виж [клуба](https://playerz.bg/x).") == "Виж клуба.")
    }

    // MARK: - Drafts

    private func proposal(_ json: String) -> AssistantProposal? {
        guard case let .answer(_, proposal) = AssistantEvent.decode(#"{"type":"answer","text":"т","proposal":\#(json)}"#)
        else { return nil }
        return proposal
    }

    @Test func aGameDraftCarriesItsPlayers() throws {
        let game = try #require(proposal("""
        {"kind":"game","draft":{"venueId":"v1","resourceId":"r1","startTs":"2026-11-22T16:00:00.000Z",
         "endTs":"2026-11-22T17:30:00Z","spots":3,"levelMin":2,"levelMax":4}}
        """))
        #expect(game.kind == .game)
        #expect(game.spots == 3 && game.levelMin == 2 && game.levelMax == 4)
        #expect(game.end.timeIntervalSince(game.start) == 90 * 60)
        let open = try #require(proposal("""
        {"kind":"game","draft":{"venueId":"v1","resourceId":"r1","startTs":"2026-11-22T16:00:00.000Z","endTs":"2026-11-22T17:00:00.000Z","spots":1}}
        """))
        #expect(open.levelMin == nil && open.levelMax == nil, "open to any level")
    }

    /// A draft that does not read costs the button, never the answer.
    @Test func anOddDraftIsNoButton() {
        #expect(proposal(#"{"kind":"lesson","draft":{"venueId":"v","resourceId":"r","startTs":"2026-11-22T16:00:00Z","endTs":"2026-11-22T17:00:00Z"}}"#) == nil)
        #expect(proposal(#"{"kind":"booking","draft":{"venueId":"v","resourceId":"r","startTs":"later","endTs":"2026-11-22T17:00:00Z"}}"#) == nil)
        #expect(proposal(#"{"kind":"booking","draft":{"venueId":"v","resourceId":"r","startTs":"2026-11-22T17:00:00Z","endTs":"2026-11-22T16:00:00Z"}}"#) == nil,
                "an end before its start")
        #expect(AssistantEvent.decode(#"{"type":"answer","text":"Ето.","proposal":{"kind":"booking"}}"#)
            == .answer(text: "Ето.", proposal: nil))
    }
}
