import Foundation
import Testing

@testable import PlayerzAPI

/// A turn in the assistant's sheet, from the question to `done`: what each
/// event leaves on screen. The events are synthetic; nothing reaches a server.
@MainActor
@Suite("The assistant's turns")
struct AssistantStoreTests {
    private final class Asked {
        var requests: [AssistantAsk] = []
    }

    private final class Hold: AssistantConnectionHold {
        var log: [String] = []
        func begin() { log.append("begin") }
        func end() { log.append("end") }
    }

    private func store(
        _ events: [AssistantEvent], throwing: Error? = nil, failing: Error? = nil,
        asked: Asked = Asked(), hold: Hold? = nil
    ) -> AssistantStore {
        AssistantStore(ask: { request in
            asked.requests.append(request)
            if let throwing { throw throwing }
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                if let failing { continuation.finish(throwing: failing) } else { continuation.finish() }
            }
        }, hold: hold)
    }

    private func ask(_ store: AssistantStore, _ question: String = "Къде има свободен корт в събота?") async {
        store.draft = question
        store.send(page: .init(.home))
        await store.settled()
        #expect(!store.asking, "the turn ended")
    }

    private let booking = AssistantProposal(
        kind: .booking, venueId: "v1", resourceId: "r2",
        start: Date(timeIntervalSince1970: 1_800_000_000), end: Date(timeIntervalSince1970: 1_800_003_600)
    )

    @Test func anAnswerWithItsDraft() async {
        let store = store([
            .conversation(id: "c1"), .thinking, .toolCall(name: "find_free_places"),
            .toolResult(name: "find_free_places", ok: true, truncated: false),
            .answer(text: "В събота от 10:00 на корт 2.", proposal: booking),
            .done(truncatedAny: false, partialAny: false),
        ])
        await ask(store)
        #expect(store.turns.count == 1)
        #expect(store.turns[0].question == "Къде има свободен корт в събота?")
        #expect(store.turns[0].phase == .answered("В събота от 10:00 на корт 2.", proposal: booking))
        #expect(store.draft == "", "the question left the field")
        #expect(store.conversationId == "c1")
    }

    /// Each next question continues the conversation the server named; «Нов
    /// разговор» starts a fresh one, and no earlier turn is ever sent.
    @Test func theNextQuestionContinuesTheConversation() async {
        let asked = Asked()
        let store = store([.conversation(id: "c1"), .answer(text: "Да.", proposal: nil),
                           .done(truncatedAny: false, partialAny: false)], asked: asked)
        await ask(store, "Първи")
        await ask(store, "Втори")
        store.newConversation()
        #expect(store.turns.isEmpty)
        await ask(store, "Трети")
        #expect(asked.requests.map(\.conversationId) == [nil, "c1", nil])
        #expect(asked.requests.map(\.message) == ["Първи", "Втори", "Трети"])
        #expect(asked.requests.allSatisfy { $0.page == .init(.home) })
    }

    @Test func theWaitNamesWhatIsBeingRead() async {
        let (events, feed) = AsyncThrowingStream<AssistantEvent, Error>.makeStream()
        let store = AssistantStore(ask: { _ in events })
        store.draft = "Кога могат всички?"
        store.send()
        #expect(store.turns[0].phase == .working(.thinking))
        feed.yield(.toolCall(name: "best_time_for_game"))
        await waitUntil { store.turns[0].phase == .working(.reading("best_time_for_game")) }
        feed.yield(.toolResult(name: "best_time_for_game", ok: true, truncated: false))
        await waitUntil { store.turns[0].phase == .working(.writing) }
        #expect(!store.canSend, "one question at a time")
        feed.yield(.answer(text: "В неделя.", proposal: nil))
        feed.yield(.done(truncatedAny: false, partialAny: false))
        feed.finish()
        await store.settled()
        #expect(store.turns[0].phase == .answered("В неделя."))
    }

    @Test func aRefusalIsNoAnswer() async {
        let store = store([.thinking, .refusal(code: "ASSISTANT_NO_GROUNDING", message: "Не намерих."),
                           .done(truncatedAny: false, partialAny: false)])
        await ask(store)
        #expect(store.turns[0].phase == .unanswered(.refusal(code: "ASSISTANT_NO_GROUNDING", message: "Не намерих.")))
    }

    /// An egress block discards an answer already shown.
    @Test func anEgressBlockDiscardsTheAnswer() async {
        let store = store([.answer(text: "Ключът е …", proposal: nil),
                           .refusal(code: "ASSISTANT_EGRESS_BLOCKED", message: nil),
                           .done(truncatedAny: false, partialAny: false)])
        await ask(store)
        #expect(store.turns[0].phase == .unanswered(.refusal(code: "ASSISTANT_EGRESS_BLOCKED", message: nil)))
    }

    /// After an answer a halt says it is incomplete; before one, why there is none.
    @Test func aHaltIsIncompleteNotAnError() async {
        let after = store([.answer(text: "Частичен отговор.", proposal: booking),
                           .halt(code: "ASSISTANT_TOOL_BUDGET", message: nil),
                           .done(truncatedAny: false, partialAny: false)])
        await ask(after)
        #expect(after.turns[0].phase == .answered(
            "Частичен отговор.", proposal: booking, notes: [.halt(code: "ASSISTANT_TOOL_BUDGET", message: nil)]))
        let before = store([.thinking, .halt(code: "ASSISTANT_SPEND_CEILING", message: "Утре пак."),
                            .done(truncatedAny: false, partialAny: false)])
        await ask(before)
        #expect(before.turns[0].phase == .unanswered(.halt(code: "ASSISTANT_SPEND_CEILING", message: "Утре пак.")))
    }

    /// `done`'s signals are said under the answer, never twice with the halt
    /// that already said them.
    @Test func donesSignalsAreSaid() async {
        let both = store([.answer(text: "А.", proposal: nil), .halt(code: "ASSISTANT_TIME_BUDGET", message: nil),
                          .done(truncatedAny: true, partialAny: true)])
        await ask(both)
        #expect(both.turns[0].phase == .answered(
            "А.", notes: [.halt(code: "ASSISTANT_TIME_BUDGET", message: nil), .partial, .truncated]))
        let once = store([.answer(text: "А.", proposal: nil), .halt(code: "ASSISTANT_PARTIAL_DATA", message: nil),
                          .done(truncatedAny: false, partialAny: true)])
        await ask(once)
        #expect(once.turns[0].phase == .answered("А.", notes: [.halt(code: "ASSISTANT_PARTIAL_DATA", message: nil)]))
    }

    @Test func aStreamThatJustEndsIsAnInterruption() async {
        let store = store([.thinking])
        await ask(store)
        #expect(store.turns[0].phase == .unanswered(.interrupted))
    }

    @Test func doneWithNoAnswerSaysSo() async {
        let store = store([.thinking, .done(truncatedAny: false, partialAny: false)])
        await ask(store)
        #expect(store.turns[0].phase == .unanswered(.noAnswer))
    }

    /// Off on this server, or not for this account: said, and the button goes.
    @Test func refusalsBeforeTheStream() async {
        let off = store([], throwing: AssistantAskError.disabled)
        await ask(off)
        #expect(off.turns[0].phase == .unanswered(.refused(.disabled)))
        #expect(off.unavailable == .disabled)
        let club = store([], throwing: AssistantAskError.playersOnly)
        await ask(club)
        #expect(club.unavailable == .playersOnly)
        let busy = store([], throwing: AssistantAskError.rateLimited)
        await ask(busy)
        #expect(busy.turns[0].phase == .unanswered(.refused(.rateLimited)))
        #expect(busy.unavailable == nil, "a limit hides nothing")
        let offline = store([], throwing: URLError(.notConnectedToInternet))
        await ask(offline)
        #expect(offline.turns[0].phase == .unanswered(.offline))
    }

    /// The connection held for the turn and given back at its end, and a
    /// connection lost mid-answer says to ask again.
    @Test func theConnectionIsHeldForTheTurn() async {
        let hold = Hold()
        let lost = store([.thinking], failing: URLError(.networkConnectionLost), hold: hold)
        await ask(lost)
        #expect(lost.turns[0].phase == .unanswered(.lostMidAnswer))
        #expect(hold.log.first == "begin")
        #expect(hold.log.last == "end")
    }

    /// A turn stopped while its stream is open must not give back the hold
    /// of the turn asked right after it.
    @Test func aStoppedTurnLeavesTheNextOnesHold() async {
        let hold = Hold()
        let first = AsyncThrowingStream<AssistantEvent, Error>.makeStream()
        let second = AsyncThrowingStream<AssistantEvent, Error>.makeStream()
        var streams = [first.stream, second.stream]
        let store = AssistantStore(ask: { _ in streams.removeFirst() }, hold: hold)
        store.draft = "Първи"
        store.send()
        await waitUntil { hold.log == ["begin"] }
        store.stop()
        store.draft = "Втори"
        store.send()
        await waitUntil { hold.log == ["begin", "end", "begin"] }
        first.continuation.finish()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(hold.log == ["begin", "end", "begin"], "the second turn is still held")
        #expect(store.asking)
        second.continuation.yield(.done(truncatedAny: false, partialAny: false))
        second.continuation.finish()
        await store.settled()
        #expect(hold.log.last == "end")
        #expect(!store.asking)
    }

    @Test func oneQuestionAtATime() {
        let store = AssistantStore(ask: { _ in AsyncThrowingStream { _ in } })
        #expect(!store.canSend, "an empty field")
        store.draft = "   "
        #expect(!store.canSend, "blank")
        store.draft = String(repeating: "я", count: AssistantAsk.maxLength + 1)
        #expect(!store.canSend, "over the server's 2000")
        store.draft = "Кога?"
        #expect(store.canSend)
        store.send()
        #expect(!store.canSend, "while a turn runs")
        store.stop()
        #expect(store.turns[0].phase == .unanswered(.interrupted), "a turn cut short says so")
    }

    /// A past conversation: each question with its answer, the next question
    /// continuing it.
    @Test func aTranscriptBecomesTheSheetsTurns() async {
        let asked = Asked()
        let store = store([.done(truncatedAny: false, partialAny: false)], asked: asked)
        store.resume(.init(id: "c9", items: [
            .init(role: .assistant, text: "Отговор без въпрос."),
            .init(role: .user, text: "Къде?"),
            .init(role: .assistant, text: "В Лозенец."),
            .init(role: .user, text: "А кога?"),
        ], truncated: true))
        #expect(store.earlierLeftOut)
        #expect(store.turns.map(\.question) == [nil, "Къде?", "А кога?"])
        #expect(store.turns.map(\.phase) == [
            .answered("Отговор без въпрос."), .answered("В Лозенец."), .unanswered(.answerNotKept),
        ])
        await ask(store, "И с кого?")
        #expect(asked.requests.first?.conversationId == "c9")
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }
}
