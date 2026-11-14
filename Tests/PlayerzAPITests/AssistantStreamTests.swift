import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// A canned SSE answer, and what the request carried.
private final class StreamTransport: ClientTransport, @unchecked Sendable {
    let status: Int
    let contentType: String
    let body: String
    private let lock = NSLock()
    private var _sent: Data?
    private var _path: String?

    init(status: Int = 200, contentType: String = "text/event-stream", body: String) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    var sent: Data? { lock.withLock { _sent } }
    var path: String? { lock.withLock { _path } }

    func send(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var data: Data?
        if let body { data = try await Data(collecting: body, upTo: 1 << 20) }
        lock.withLock {
            _sent = data
            _path = request.path
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: contentType]),
            HTTPBody(self.body)
        )
    }
}

/// `POST /assistant/stream` (projectZ#704) through the generated client: the
/// events as the server writes them, the request as it must be sent, and the
/// refusals before the stream opens.
@Suite("The assistant's stream")
struct AssistantStreamTests {
    private func client(_ transport: StreamTransport) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: transport)
    }

    private func events(_ body: String) async throws -> [AssistantEvent] {
        var seen: [AssistantEvent] = []
        for try await event in try await AssistantAPI.ask(.init(message: "Кога?"), client: client(.init(body: body))) {
            seen.append(event)
        }
        return seen
    }

    /// A whole turn in the server's order, with a heartbeat comment, an event
    /// this build does not know and a line that is not JSON among them.
    @Test func aWholeTurnDecodesInOrder() async throws {
        let seen = try await events(TURN)
        #expect(seen == [
            .conversation(id: "conv_1"),
            .thinking,
            .toolCall(name: "find_free_places"),
            .toolResult(name: "find_free_places", ok: true, truncated: false),
            .unknown(type: "answer_delta"),
            .answer(
                text: "Свободно е в събота от 10:00 на корт 2.",
                proposal: AssistantProposal(
                    kind: .booking, venueId: "v1", resourceId: "r2",
                    start: try #require(AssistantProposal.instant("2026-11-21T08:00:00.000Z")),
                    end: try #require(AssistantProposal.instant("2026-11-21T09:00:00.000Z"))
                )
            ),
            .done(truncatedAny: false, partialAny: false),
        ])
    }

    /// A halt does not end the reading: `done` still comes after it.
    @Test func aHaltIsFollowedByDone() async throws {
        let seen = try await events("""
        data: {"type":"conversation","conversationId":"c"}

        data: {"type":"halt","code":"ASSISTANT_SPEND_CEILING","message":"Достигнахте дневния лимит."}

        data: {"type":"done","truncatedAny":true,"partialAny":false}


        """)
        #expect(seen.suffix(2) == [
            .halt(code: "ASSISTANT_SPEND_CEILING", message: "Достигнахте дневния лимит."),
            .done(truncatedAny: true, partialAny: false),
        ])
    }

    @Test func aRefusalCarriesItsCodeAndSentence() {
        #expect(AssistantEvent.decode(#"{"type":"refusal","code":"ASSISTANT_DECLINED","message":"Не мога."}"#)
            == .refusal(code: "ASSISTANT_DECLINED", message: "Не мога."))
        #expect(AssistantEvent.decode(#"{"type":"conversation"}"#) == .unknown(type: "conversation"),
                "no id costs the follow-up, never the turn")
        #expect(AssistantEvent.decode("not json") == nil)
        #expect(AssistantEvent.decode(#"{"type":"tool_result","name":"x"}"#)
            == .toolResult(name: "x", ok: false, truncated: false))
    }

    /// The body is the question, the conversation it continues, the screen
    /// and the place: the contract's names, nothing else.
    @Test func theRequestCarriesTheContractsFields() async throws {
        let transport = StreamTransport(body: "data: {\"type\":\"done\",\"truncatedAny\":false,\"partialAny\":false}\n\n")
        let ask = AssistantAsk(
            message: "Кога да играем пак?", conversationId: "conv_1",
            page: .booking("b_9"), location: (lat: 42.69, lng: 23.32)
        )
        for try await _ in try await AssistantAPI.ask(ask, client: client(transport)) {}
        #expect(transport.path == "/assistant/stream")
        let sent = try #require(transport.sent)
        let json = try #require(try JSONSerialization.jsonObject(with: sent) as? [String: Any])
        #expect(Set(json.keys) == ["message", "conversationId", "page", "location"])
        #expect(json["message"] as? String == "Кога да играем пак?")
        #expect(json["conversationId"] as? String == "conv_1")
        #expect(json["page"] as? [String: String] == ["screen": "booking", "bookingId": "b_9"])
        let place = try #require(json["location"] as? [String: Double])
        #expect(place["lat"] == 42.69 && place["lng"] == 23.32)
    }

    /// A first question: no conversation, no page, no place: absent, not null.
    @Test func aFirstQuestionSendsOnlyTheQuestion() async throws {
        let transport = StreamTransport(body: "")
        for try await _ in try await AssistantAPI.ask(.init(message: "Здравей"), client: client(transport)) {}
        let sent = try #require(transport.sent)
        let json = try #require(try JSONSerialization.jsonObject(with: sent) as? [String: Any])
        #expect(Set(json.keys) == ["message"])
    }

    @Test(arguments: [
        (404, "ASSISTANT_DISABLED", AssistantAskError.disabled),
        (403, "ASSISTANT_PLAYERS_ONLY", .playersOnly),
        (429, "RATE_LIMITED", .rateLimited),
        (400, "BAD_REQUEST", .badRequest),
        (401, "UNAUTHORIZED", .signedOut),
        (500, "INTERNAL", .failed(message: "Нещо се обърка.")),
    ])
    func refusalsBeforeTheStream(status: Int, code: String, expected: AssistantAskError) async {
        let transport = StreamTransport(
            status: status, contentType: "application/json",
            body: #"{"error":{"code":"\#(code)","message":"Нещо се обърка."}}"#
        )
        await #expect(throws: expected) {
            _ = try await AssistantAPI.ask(.init(message: "?"), client: client(transport))
        }
    }

    /// The launcher's question: 200 on the memory list is on, 404 is off,
    /// anything else is "do not know" and changes nothing.
    @Test func whetherItIsOffered() async {
        let on = Canned(replies: ["listAssistantMemory": (200, #"{"data":{"items":[]}}"#)])
        let off = Canned(replies: ["listAssistantMemory": (404, #"{"error":{"code":"ASSISTANT_DISABLED","message":"x"}}"#)])
        let down = Canned(replies: ["listAssistantMemory": (500, #"{"error":{"code":"INTERNAL","message":"x"}}"#)])
        let url = URL(string: "https://playerz.test/api/v1")!
        #expect(await AssistantAPI.isOffered(client: Playerz.client(baseURL: url, transport: on)) == true)
        #expect(await AssistantAPI.isOffered(client: Playerz.client(baseURL: url, transport: off)) == false)
        #expect(await AssistantAPI.isOffered(client: Playerz.client(baseURL: url, transport: down)) == nil)
    }

    @Test func theServersSentenceOnlyInTheAppsLanguage() {
        #expect(ServerSentence.fits("Достигнахте дневния лимит.", bulgarian: true))
        #expect(!ServerSentence.fits("Daily limit reached.", bulgarian: true))
        #expect(ServerSentence.fits("Daily limit reached.", bulgarian: false))
        #expect(!ServerSentence.fits("Достигнахте лимита.", bulgarian: false))
        #expect(!ServerSentence.fits("  ", bulgarian: true))
        #expect(!ServerSentence.fits(nil, bulgarian: true))
    }
}

/// The server's events, as `docs/assistant.md` orders them: `: keep-alive`
/// comments between, one event this build does not know, and one line that
/// is not JSON at all.
private let TURN = """
: keep-alive

data: {"type":"conversation","conversationId":"conv_1"}

data: {"type":"thinking"}

data: {"type":"tool_call","name":"find_free_places"}

: keep-alive

data: {"type":"tool_result","name":"find_free_places","ok":true,"truncated":false}

data: {"type":"answer_delta","text":"Свободно","seq":0}

data: {broken

data: {"type":"answer","text":"Свободно е в събота от 10:00 на корт 2.","proposal":{"kind":"booking","draft":{"venueId":"v1","resourceId":"r2","startTs":"2026-11-21T08:00:00.000Z","endTs":"2026-11-21T09:00:00.000Z"}}}

data: {"type":"done","truncatedAny":false,"partialAny":false}


"""
