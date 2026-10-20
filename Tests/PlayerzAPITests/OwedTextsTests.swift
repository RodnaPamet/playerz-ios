import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers each operation with a status and body.
private struct Replies: ClientTransport {
    let replies: [String: (Int, String)]

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let (status, json) = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: "application/json"]),
            HTTPBody(json)
        )
    }
}

private let SIGNED_IN = """
    {"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z",
    "expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}
    """

private func signedIn(_ replies: [String: (Int, String)]) async throws -> PlayerzSession {
    var all = replies
    all["authSignIn"] = (200, SIGNED_IN)
    let session = PlayerzSession(
        baseURL: URL(string: "https://playerz.test")!,
        persistence: MemoryPersistence(),
        transport: Replies(replies: all)
    )
    try await session.signIn(email: "ivan@playerz.test", password: "pw")
    return session
}

private func standing(due: String, current: String = #"{"terms":"2026-11-01","privacy":"2026-11-01"}"#) -> String {
    #"{"data":{"current":\#(current),"accepted":{},"due":\#(due)}}"#
}

@Suite("The terms step (playerz-ios#10)")
struct OwedTextsTests {
    @Test func newTextsAreOwedWithTheirVersions() async throws {
        let session = try await signedIn(["getLegalStanding": (200, standing(due: #"["terms","privacy"]"#))])
        let owed = try await session.owedTexts()
        #expect(owed.texts == [.init(id: "terms", version: "2026-11-01"), .init(id: "privacy", version: "2026-11-01")])
    }

    @Test func nothingPublishedMeansNothingOwed() async throws {
        let session = try await signedIn(["getLegalStanding": (200, standing(due: "[]", current: "{}"))])
        #expect(try await session.owedTexts().isEmpty)
    }

    @Test func aTextTheSpecDoesNotKnowIsAFailureNotNothingOwed() async throws {
        let session = try await signedIn(["getLegalStanding": (200, standing(due: #"["cookies"]"#))])
        await #expect(throws: LegalStepError.failed) { _ = try await session.owedTexts() }
    }

    @Test func acceptingLeavesNothingOwed() async throws {
        let session = try await signedIn(["acceptLegal": (200, standing(due: "[]"))])
        #expect(try await session.acceptTexts().isEmpty)
    }

    @Test(arguments: [(401, LegalStepError.notSignedIn), (429, .rateLimited), (500, .failed)])
    func aRefusedAcceptanceSaysWhy(status: Int, expected: LegalStepError) async throws {
        let session = try await signedIn(["acceptLegal": (status, #"{"error":{"code":"X","message":"no"}}"#)])
        await #expect(throws: expected) { _ = try await session.acceptTexts() }
    }
}
