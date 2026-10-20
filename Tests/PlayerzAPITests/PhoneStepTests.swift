import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers each operation with a status and body, and keeps the JSON it was sent.
private actor Replies: ClientTransport {
    private let replies: [String: (Int, String)]
    private(set) var sent: [String: String] = [:]

    init(_ replies: [String: (Int, String)]) { self.replies = replies }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if let body { sent[operationID] = try await String(collecting: body, upTo: 1 << 16) }
        guard let (status, json) = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: "application/json"]),
            HTTPBody(json)
        )
    }

    func body(_ operationID: String) -> String? { sent[operationID] }
}

private let SIGNED_IN = """
    {"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z",
    "expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}
    """

private func signedIn(_ replies: [String: (Int, String)]) async throws -> (PlayerzSession, Replies) {
    var all = replies
    all["authSignIn"] = (200, SIGNED_IN)
    let transport = Replies(all)
    let session = PlayerzSession(
        baseURL: URL(string: "https://playerz.test")!,
        persistence: MemoryPersistence(),
        transport: transport
    )
    try await session.signIn(email: "ivan@playerz.test", password: "pw")
    return (session, transport)
}

private func refusal(_ code: String) -> String { #"{"error":{"code":"\#(code)","message":"no"}}"# }

@Suite("The phone step (playerz-ios#11)")
struct PhoneStepTests {
    @Test func aCodeIsSentAndItsChallengeKept() async throws {
        let sent = #"{"data":{"sent":true,"number":"+35988*****56","challenge":"c-0123456789abcdef"}}"#
        let (session, transport) = try await signedIn(["startPhoneVerification": (200, sent)])

        let code = try await session.startPhone("0888 123 456")

        #expect(code == PhoneCode(maskedNumber: "+35988*****56", challenge: "c-0123456789abcdef"))
        let body = try #require(await transport.body("startPhoneVerification"))
        #expect(try JSONDecoder().decode([String: String].self, from: Data(body.utf8)) == ["phone": "0888 123 456"])
    }

    @Test(arguments: [
        ("startPhoneVerification", 400, "PHONE_INVALID", PhoneStepError.invalidNumber),
        ("startPhoneVerification", 429, "RATE_LIMITED", .rateLimited),
        ("startPhoneVerification", 503, "PHONE_VERIFY_UNAVAILABLE", .unavailable),
    ])
    func aRefusedCodeSaysWhy(operation: String, status: Int, code: String, expected: PhoneStepError) async throws {
        let (session, _) = try await signedIn([operation: (status, refusal(code))])
        await #expect(throws: expected) { _ = try await session.startPhone("0888") }
    }

    @Test func theCodeConfirmsTheNumber() async throws {
        let (session, transport) = try await signedIn(["confirmPhoneVerification": (200, CONFIRMED_ME)])

        try await session.confirmPhone("0888 123 456", code: "123 456", challenge: "c-0123456789abcdef")

        let body = try #require(await transport.body("confirmPhoneVerification"))
        let sent = try JSONDecoder().decode([String: String].self, from: Data(body.utf8))
        #expect(sent == ["phone": "0888 123 456", "code": "123 456", "challenge": "c-0123456789abcdef"])
    }

    @Test(arguments: [
        (400, "PHONE_CODE_WRONG", PhoneStepError.wrongCode),
        (400, "PHONE_CODE_EXPIRED", .expiredCode),
        (409, "PHONE_IN_USE", .numberInUse),
        (429, "RATE_LIMITED", .rateLimited),
        (503, "PHONE_VERIFY_UNAVAILABLE", .unavailable),
    ])
    func aRefusedConfirmationSaysWhy(status: Int, code: String, expected: PhoneStepError) async throws {
        let (session, _) = try await signedIn(["confirmPhoneVerification": (status, refusal(code))])
        await #expect(throws: expected) {
            try await session.confirmPhone("0888", code: "1", challenge: "c-0123456789abcdef")
        }
    }
}

/// The account as `POST /me/phone/confirm` answers it: the number confirmed.
private let CONFIRMED_ME = """
    {"data": {"id": "u2", "name": "Мария", "email": "maria@playerz.test", "avatarUrl": null, "locale": "bg",
      "sports": [], "accountKind": "PLAYER",
      "landing": {"reason": "player", "club": null},
      "searchable": true, "phone": {"required": true, "verified": true, "number": "+35988*****56"}, "ratingPublic": true}}
    """
