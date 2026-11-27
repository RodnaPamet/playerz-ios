import Foundation
import Testing

@testable import PlayerzAPI

/// «Какво помни асистентът»: the points, forgotten one at a time behind a
/// few seconds of «Отмени», all at once, or corrected; and the past
/// conversations. The store's server is closures that record what they were
/// asked; the wire is the server's JSON through the generated client.
@MainActor
@Suite("What the assistant remembers")
struct AssistantMemoryTests {
    private typealias Point = AssistantMemory.Point

    private let padel = Point(id: "m1", text: "Играе падел, ниво около 3.", rememberedAt: .distantPast)
    private let evenings = Point(id: "m2", text: "Предпочита вечерни часове.", rememberedAt: .distantPast)

    private final class Calls {
        var log: [String] = []
        var refusal: Error?
    }

    private func store(_ calls: Calls) -> AssistantMemoryStore {
        let points = [padel, evenings]
        return AssistantMemoryStore(window: .seconds(600), api: .init(
            list: { points },
            forget: { id in
                calls.log.append("forget \(id)")
                if let refusal = calls.refusal { throw refusal }
            },
            forgetAll: {
                calls.log.append("forget all")
                if let refusal = calls.refusal { throw refusal }
            },
            edit: { id, text in
                calls.log.append("edit \(id) \(text)")
                if let refusal = calls.refusal { throw refusal }
                return Point(id: id, text: text, rememberedAt: .now, editedByPerson: true)
            }
        ))
    }

    // MARK: - The wire

    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func thePointsDecode() async throws {
        let points = try await AssistantAPI.points(client: client(["listAssistantMemory": (200, """
        {"data":{"items":[
          {"id":"m1","text":"Играе падел.","rememberedAt":"2026-11-14T08:15:00.000Z","editedByPerson":false},
          {"id":"m2","text":"Казва се Иво.","rememberedAt":"2026-11-13T19:00:00Z","editedByPerson":true}
        ]}}
        """)]))
        #expect(points.map(\.id) == ["m1", "m2"])
        #expect(points[1].editedByPerson)
    }

    @Test func refusalsAreCodes() async {
        let off = client(["listAssistantMemory": (404, #"{"error":{"code":"ASSISTANT_DISABLED","message":"x"}}"#)])
        await #expect(throws: AssistantMemoryError.disabled) { _ = try await AssistantAPI.points(client: off) }
        let empty = client(["editAssistantMemoryPoint": (400, #"{"error":{"code":"MEMORY_POINT_EMPTY","message":"x"}}"#)])
        await #expect(throws: AssistantMemoryError.empty) {
            _ = try await AssistantAPI.editPoint("m1", text: "<b></b>", client: empty)
        }
        // Gone already is what was asked for.
        let gone = client(["forgetAssistantMemoryPoint": (404, #"{"error":{"code":"MEMORY_POINT_NOT_FOUND","message":"x"}}"#)])
        try? await AssistantAPI.forgetPoint("m1", client: gone)
        let goneConversation = client([
            "deleteAssistantConversation": (404, #"{"error":{"code":"ASSISTANT_CONVERSATION_NOT_FOUND","message":"x"}}"#),
        ])
        await #expect(throws: Never.self) {
            try await AssistantAPI.deleteConversation("c1", client: goneConversation)
        }
        // But a server with the assistant off is not "gone".
        let offDelete = client(["deleteAssistantConversation": (404, #"{"error":{"code":"ASSISTANT_DISABLED","message":"x"}}"#)])
        await #expect(throws: AssistantMemoryError.disabled) {
            try await AssistantAPI.deleteConversation("c1", client: offDelete)
        }
    }

    @Test func theConversationsDecode() async throws {
        let list = try await AssistantAPI.conversations(client: client(["listAssistantConversations": (200, """
        {"data":{"items":[
          {"id":"c1","startedAt":"2026-11-14T08:00:00.000Z","lastTurnAt":"2026-11-14T08:05:00.000Z","turns":4,"opening":"Къде има корт?"},
          {"id":"c2","startedAt":"2026-11-13T08:00:00.000Z","lastTurnAt":"2026-11-13T08:01:00.000Z","turns":2,"opening":null}
        ]}}
        """)]))
        #expect(list.map(\.opening) == ["Къде има корт?", nil])
        #expect(list[0].turns == 4)
        let one = try await AssistantAPI.conversation("c1", client: client(["getAssistantConversation": (200, """
        {"data":{"id":"c1","startedAt":"2026-11-14T08:00:00.000Z","lastTurnAt":"2026-11-14T08:05:00.000Z","turns":2,
          "items":[{"role":"user","text":"Къде?","at":"2026-11-14T08:00:00.000Z"},
                   {"role":"assistant","text":"В Лозенец.","at":"2026-11-14T08:00:09.000Z"}],
          "truncated":false}}
        """)]))
        #expect(one.items == [.init(role: .user, text: "Къде?"), .init(role: .assistant, text: "В Лозенец.")])
        #expect(!one.truncated)
    }

    // MARK: - One at a time, with «Отмени»

    @Test func undoSendsNothing() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        #expect(memory.items == [evenings], "gone from the list at once")
        #expect(memory.undoable == padel)
        memory.undo()
        #expect(memory.items == [padel, evenings])
        await memory.commit(padel)
        #expect(calls.log.isEmpty, "an undone point is never sent, even if its window fires late")
    }

    @Test func theWindowForgetsItOnce() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        await memory.commit(padel)
        await memory.commit(padel)
        #expect(calls.log == ["forget m1"])
        #expect(memory.value == [evenings], "out of the list itself, not only hidden")
        #expect(memory.hidden.isEmpty)
        #expect(memory.undoable == nil)
    }

    @Test func aSecondSwipeSendsTheFirst() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        memory.forget(evenings)
        #expect(memory.undoable == evenings)
        await settle { calls.log == ["forget m1"] }
        memory.undo()
        #expect(memory.items == [evenings], "«Отмени» brings back the one it names")
    }

    @Test func leavingSendsWhatWasSwiped() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        memory.flush()
        await settle { calls.log == ["forget m1"] }
        await memory.commit(padel)
        memory.flush()
        #expect(calls.log == ["forget m1"], "sent once")
    }

    @Test func aRefusalBringsItBack() async {
        let calls = Calls()
        calls.refusal = AssistantMemoryError.rateLimited
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        await memory.commit(padel)
        #expect(memory.items == [padel, evenings])
        #expect(memory.failure == .rateLimited)
    }

    @Test func forgetAllEmptiesTheListAndCancelsTheWindow() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        await memory.forgetAll()
        #expect(calls.log == ["forget all"], "the swiped point goes with the rest")
        #expect(memory.items.isEmpty)
        await memory.commit(padel)
        #expect(calls.log == ["forget all"])
    }

    @Test func aRefusedForgetAllKeepsEverything() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        memory.forget(padel)
        calls.refusal = URLError(.timedOut)
        await memory.forgetAll()
        #expect(memory.items == [padel, evenings])
        #expect(memory.failure == .failed)
    }

    // MARK: - A correction

    @Test func anEmptyCorrectionIsRefusedBeforeSending() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        #expect(await memory.edit(padel, to: "  \n ") == .empty)
        #expect(calls.log.isEmpty)
    }

    @Test func aCorrectionIsTrimmedCappedAndShown() async {
        let calls = Calls()
        let memory = store(calls)
        await memory.load()
        let long = String(repeating: "я", count: Point.maxLength + 20)
        #expect(await memory.edit(padel, to: "  \(long)\n") == nil)
        let sent = String(repeating: "я", count: Point.maxLength)
        #expect(calls.log == ["edit m1 \(sent)"])
        #expect(memory.items.first?.text == sent)
        #expect(memory.items.first?.editedByPerson == true)
    }

    @Test func aCorrectionOfAGonePointDropsIt() async {
        let calls = Calls()
        calls.refusal = AssistantMemoryError.notFound
        let memory = store(calls)
        await memory.load()
        #expect(await memory.edit(padel, to: "Играе тенис.") == .notFound)
        #expect(memory.items == [evenings])
    }

    @Test func aFailedFirstLoadSaysWhy() async {
        let memory = AssistantMemoryStore(api: .init(
            list: { throw AssistantMemoryError.disabled }, forget: { _ in }, forgetAll: {}))
        await memory.load()
        #expect(memory.state == .failed(.disabled))
    }

    private func settle(_ done: () -> Bool) async {
        for _ in 0..<200 where !done() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}
