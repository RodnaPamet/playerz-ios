import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers each operation with a status and body, and keeps what was sent.
private actor Sent: ClientTransport {
    private let replies: [String: (Int, String)]
    private(set) var bodies: [String: String] = [:]

    init(_ replies: [String: (Int, String)]) { self.replies = replies }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if let body { bodies[operationID] = try await String(collecting: body, upTo: 1 << 16) }
        guard let (status, json) = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: "application/json"]),
            HTTPBody(json)
        )
    }

    func body(_ operationID: String) -> String? { bodies[operationID] }
}

/// The account's language from the app's (playerz-ios#13), against the
/// server's answers to `PATCH /me` captured on the perf database: `en`
/// stored, and `de` refused.
@Suite("Saving the app's language to the account")
struct LanguageTests {
    private func session(_ reply: (Int, String)) async throws -> (PlayerzSession, Sent) {
        let transport = Sent([
            "authSignIn": (200, SIGNED_IN),
            "updateMe": reply,
        ])
        let session = PlayerzSession(
            baseURL: URL(string: "https://playerz.test")!,
            persistence: MemoryPersistence(),
            transport: transport
        )
        try await session.signIn(email: "ivan@playerz.test", password: "pw")
        return (session, transport)
    }

    @Test func theLanguageIsSentAndStored() async throws {
        let (session, sent) = try await session((200, ME_IN_ENGLISH))
        #expect(await session.saveLanguage(.en))
        let body = try #require(await sent.body("updateMe"))
        #expect(try JSONDecoder().decode([String: String].self, from: Data(body.utf8)) == ["locale": "en"])
    }

    @Test func aRefusalIsReportedNotThrown() async throws {
        let (session, _) = try await session((400, REFUSED))
        #expect(await !session.saveLanguage(.bg))
    }

    @Test func theAnswerDecodes() async throws {
        let client = Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: ["updateMe": (200, ME_IN_ENGLISH)])
        )
        let me = try await client.updateMe(body: .json(.init(locale: .en))).ok.body.json.data
        #expect(me.locale == "en")
    }
}

private let SIGNED_IN = #"{"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z","expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}"#
private let ME_IN_ENGLISH = #"{"data":{"id":"cmvgxxk1o003icdizwjo75n2u","name":"Георги Петров","email":"player@perf.playerz.test","avatarUrl":null,"locale":"en","sports":[],"searchable":true,"ratingPublic":true,"accountKind":"PLAYER","phone":{"required":false,"verified":false,"number":null},"landing":{"reason":"player","club":null}}}"#
private let REFUSED = #"{"error":{"code":"BAD_REQUEST","message":"Invalid profile","requestId":"6acf3dad-2fae-4158-8859-0e47b4e59565","details":{"field":"locale","issues":[{"path":["locale"],"code":"invalid_value","message":"Invalid input"}]}}}"#
