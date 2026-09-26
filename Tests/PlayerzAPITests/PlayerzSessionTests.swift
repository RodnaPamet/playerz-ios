import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers canned JSON, and records what was asked.
private actor StubTransport: ClientTransport {
    struct Reply { let status: Int; let body: String }

    private var replies: [String: Reply]
    private(set) var calls: [String] = []

    init(_ replies: [String: Reply]) { self.replies = replies }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        calls.append(operationID)
        guard let reply = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(
                status: .init(code: reply.status),
                headerFields: [.contentType: "application/json"]
            ),
            HTTPBody(reply.body)
        )
    }

    func recorded() -> [String] { calls }
}

/// Succeeds for some operations and THROWS for others.
///
/// A 500 is not the interesting failure: the generated client turns it into an
/// `.undocumented` case rather than throwing, so a sign-out ordered
/// server-call-first still reaches the local clear. A dropped connection does
/// throw, and that is the case that decides whether the token survives on the
/// device.
private actor FlakyTransport: ClientTransport {
    struct Offline: Error {}

    private let ok: [String: String]
    private let offline: Set<String>

    init(ok: [String: String], offline: Set<String>) {
        self.ok = ok
        self.offline = offline
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if offline.contains(operationID) { throw Offline() }
        guard let json = ok[operationID] else { return (HTTPResponse(status: .notFound), nil) }
        return (
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            HTTPBody(json)
        )
    }
}

private func tokensJSON(refresh: String?) -> String {
    let refreshField = refresh.map { "\"\($0)\"" } ?? "null"
    return """
    {"data":{"tokenType":"Bearer","accessToken":"access-1",
    "expiresAt":"2030-01-01T00:00:00Z","expiresIn":900,
    "refreshToken":\(refreshField),"refreshExpiresAt":"2030-02-01T00:00:00Z"}}
    """
}

private let BASE = URL(string: "https://api.playerz.test")!

@Suite("PlayerzSession")
struct PlayerzSessionTests {
    @Test("a successful sign-in stores the session")
    func signInStores() async throws {
        let persistence = MemoryPersistence()
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: persistence,
            transport: StubTransport(["authSignIn": .init(status: 200, body: tokensJSON(refresh: "r1"))])
        )

        try await session.signIn(email: "a@b.bg", password: "pw")

        #expect(await session.isSignedIn)
        #expect(persistence.peek?.accessToken == "access-1")
        #expect(persistence.peek?.refreshToken == "r1", "it must reach the Keychain, not just memory")
    }

    @Test("a sign-in with NO refresh token is refused")
    func signInWithoutRefreshTokenFails() async throws {
        // The server omits refreshToken only on a REFRESH inside its rotation
        // grace window. On a sign-in it would leave a session that dies with
        // its 15-minute access token and cannot be renewed — a "success" the
        // user experiences as being logged out a quarter of an hour later.
        let persistence = MemoryPersistence()
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: persistence,
            transport: StubTransport(["authSignIn": .init(status: 200, body: tokensJSON(refresh: nil))])
        )

        await #expect(throws: SessionError.noRefreshToken) {
            try await session.signIn(email: "a@b.bg", password: "pw")
        }
        #expect(await session.isSignedIn == false)
        #expect(persistence.peek == nil, "a half-session must not be stored")
    }

    @Test("401 is invalidCredentials, not a generic failure")
    func unauthorizedMapsCleanly() async throws {
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: MemoryPersistence(),
            transport: StubTransport([
                "authSignIn": .init(status: 401, body: #"{"error":{"code":"UNAUTHORIZED","message":"no"}}"#)
            ])
        )

        await #expect(throws: SessionError.invalidCredentials) {
            try await session.signIn(email: "a@b.bg", password: "wrong")
        }
    }

    @Test("429 is distinguishable from a wrong password")
    func throttledMapsCleanly() async throws {
        // These must differ: "wrong password" sends someone to reset a password
        // that works. The server throttles per IP on attempt eleven regardless
        // of whether the address exists.
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: MemoryPersistence(),
            transport: StubTransport([
                "authSignIn": .init(status: 429, body: #"{"error":{"code":"RATE_LIMITED","message":"no"}}"#)
            ])
        )

        await #expect(throws: SessionError.throttled) {
            try await session.signIn(email: "a@b.bg", password: "pw")
        }
    }

    @Test("signing out clears the Keychain even when the server call fails")
    func signOutIsLocalFirst() async throws {
        // A 500 from logout must not leave a usable token on the device. The
        // user asked to be signed out of THIS phone, and that is the part they
        // cannot fix themselves.
        let persistence = MemoryPersistence()
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: persistence,
            transport: StubTransport([
                "authSignIn": .init(status: 200, body: tokensJSON(refresh: "r1")),
                "authLogout": .init(status: 500, body: #"{"error":{"code":"OOPS","message":"no"}}"#),
            ])
        )
        try await session.signIn(email: "a@b.bg", password: "pw")

        try await session.signOut()

        #expect(await session.isSignedIn == false)
        #expect(persistence.peek == nil)
    }

    @Test("signing out clears the Keychain even with NO CONNECTION")
    func signOutSurvivesAnOfflineServer() async throws {
        // The load-bearing version of the test above. A 500 does not throw —
        // the client returns an undocumented case — so ordering the server call
        // first still happened to work. A dropped connection throws, and if the
        // logout is awaited before the local clear, the throw escapes and the
        // token STAYS ON THE DEVICE after the user asked to be signed out.
        let persistence = MemoryPersistence()
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: persistence,
            transport: FlakyTransport(
                ok: ["authSignIn": tokensJSON(refresh: "r1")],
                offline: ["authLogout"]
            )
        )
        try await session.signIn(email: "a@b.bg", password: "pw")
        #expect(persistence.peek != nil)

        try await session.signOut()

        #expect(await session.isSignedIn == false)
        #expect(persistence.peek == nil, "a token left behind is the one thing the user cannot fix")
    }

    @Test("a restored session is signed in without signing in again")
    func restoresFromPersistence() async throws {
        // Relaunching the app must not ask for a password.
        let persistence = MemoryPersistence(
            Tokens(
                accessToken: "a",
                accessExpiresAt: Date().addingTimeInterval(900),
                refreshToken: "r",
                refreshExpiresAt: Date().addingTimeInterval(86_400)
            )
        )
        let session = PlayerzSession(
            baseURL: BASE,
            persistence: persistence,
            transport: StubTransport([:])
        )

        #expect(await session.isSignedIn)
    }
}
