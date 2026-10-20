import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers `getAppConfig`, and keeps whether a token came with it.
private actor Config: ClientTransport {
    private let reply: (Int, String)
    private(set) var authorization: String?

    init(_ status: Int, _ body: String) { reply = (status, body) }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if operationID == "authSignIn" {
            let tokens = #"{"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z","expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}"#
            return (HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), HTTPBody(tokens))
        }
        authorization = request.headerFields[.authorization]
        return (
            HTTPResponse(status: .init(code: reply.0), headerFields: [.contentType: "application/json"]),
            HTTPBody(reply.1)
        )
    }

    func sentToken() -> String? { authorization }
}

@Suite("Module switches (playerz-ios#16)")
struct ModulesTests {
    private func session(_ transport: Config) -> PlayerzSession {
        PlayerzSession(baseURL: URL(string: "https://playerz.test")!, persistence: MemoryPersistence(), transport: transport)
    }

    @Test func productionsSwitchesAreRead() async throws {
        // As production answered on 2026-10-20.
        let body = #"{"data":{"modules":{"openPlay":true,"messaging":true,"coaches":false,"ranking":false}}}"#
        let modules = try #require(await session(Config(200, body)).modules())
        #expect(modules == Modules(openPlay: true, messaging: true, coaches: false, ranking: false))
    }

    @Test func theSwitchesAreAskedWithoutTheSessionsToken() async throws {
        let transport = Config(200, #"{"data":{"modules":{"openPlay":true,"messaging":true,"coaches":true,"ranking":true}}}"#)
        let signedIn = session(transport)
        try await signedIn.signIn(email: "ivan@playerz.test", password: "pw")
        _ = await signedIn.modules()
        #expect(await transport.sentToken() == nil, "public: the same for everyone")
    }

    @Test func aServerThatCannotSayGivesNothingToActOn() async throws {
        #expect(await session(Config(500, #"{"error":{"code":"INTERNAL","message":"no"}}"#)).modules() == nil)
        #expect(await session(Config(200, #"{"data":{}}"#)).modules() == nil)
    }
}
