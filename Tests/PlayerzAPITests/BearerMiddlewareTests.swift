import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

private let BASE = URL(string: "https://api.playerz.bg/api/v1")!

private func tokens(
    access: String = "access-1",
    accessIn: TimeInterval = 900,
    refresh: String = "refresh-1"
) -> Tokens {
    Tokens(
        accessToken: access,
        accessExpiresAt: Date().addingTimeInterval(accessIn),
        refreshToken: refresh,
        refreshExpiresAt: Date().addingTimeInterval(30 * 24 * 3600)
    )
}

/// Runs the middleware and reports the Authorization header it produced.
private func authHeaderFor(
    operationID: String,
    store: TokenStore,
    refresh: @escaping @Sendable (String) async throws -> Tokens = { _ in tokens() }
) async throws -> String? {
    let mw = BearerMiddleware(tokens: store, refresh: refresh)
    let seen = Captured()
    _ = try await mw.intercept(
        HTTPRequest(method: .get, scheme: "https", authority: "api.playerz.bg", path: "/x"),
        body: nil,
        baseURL: BASE,
        operationID: operationID
    ) { req, _, _ in
        await seen.set(req.headerFields[.authorization])
        return (HTTPResponse(status: .ok), nil)
    }
    return await seen.value
}

private actor Captured {
    var value: String?
    func set(_ v: String?) { value = v }
}

@Suite("BearerMiddleware")
struct BearerMiddlewareTests {
    @Test("attaches the access token to an authenticated operation")
    func attachesToken() async throws {
        let store = TokenStore(persistence: MemoryPersistence(tokens()))
        #expect(try await authHeaderFor(operationID: "getTenantMe", store: store) == "Bearer access-1")
    }

    @Test("refreshes first when the token is expired, and sends the NEW one")
    func refreshesBeforeSending() async throws {
        let store = TokenStore(persistence: MemoryPersistence(tokens(accessIn: -10)))
        let header = try await authHeaderFor(operationID: "createBooking", store: store) { _ in
            tokens(access: "access-2")
        }
        #expect(header == "Bearer access-2", "a stale token must never reach the wire")
    }

    @Test("sends no Authorization header when signed out")
    func signedOutSendsNothing() async throws {
        // The request still goes and the server answers 401. Throwing here
        // instead would break screens that are perfectly usable signed out.
        let store = TokenStore(persistence: MemoryPersistence(nil))
        #expect(try await authHeaderFor(operationID: "getTenantMe", store: store) == nil)
    }

    @Test(arguments: ["authSignIn", "authRefresh"])
    func authOperationsCarryNoToken(operationID: String) async throws {
        // `authRefresh` above all. It is what the refresh closure calls, so a
        // token on it means `validAccessToken` is re-entered while already
        // refreshing. A live session makes this the dangerous case, not an
        // expired one — so the store here holds a perfectly good token.
        let store = TokenStore(persistence: MemoryPersistence(tokens()))
        #expect(try await authHeaderFor(operationID: operationID, store: store) == nil)
    }

    @Test(arguments: ["listVenues", "findVenuesNear", "getVenue", "getVenueAvailability"])
    func publicDiscoveryCarriesNoToken(operationID: String) async throws {
        // These work signed out. Sending a token would only widen what a
        // logged-out browse can be correlated with, for no functional gain.
        let store = TokenStore(persistence: MemoryPersistence(tokens()))
        #expect(try await authHeaderFor(operationID: operationID, store: store) == nil)
    }

    @Test("an unauthenticated operation never triggers a refresh")
    func unauthenticatedDoesNotRefresh() async throws {
        // The reason authRefresh is exempt is recursion, so it is not enough
        // that the header is absent — the refresh path must not be entered.
        let store = TokenStore(persistence: MemoryPersistence(tokens(accessIn: -10)))
        let refreshes = Counter()

        _ = try await authHeaderFor(operationID: "authRefresh", store: store) { _ in
            await refreshes.bump()
            return tokens(access: "access-2")
        }

        #expect(await refreshes.value == 0, "refreshing inside a refresh is the recursion this prevents")
    }

    @Test("passes the body and base URL through untouched")
    func passesThrough() async throws {
        let store = TokenStore(persistence: MemoryPersistence(tokens()))
        let mw = BearerMiddleware(tokens: store, refresh: { _ in tokens() })
        let seen = Captured()

        let (response, _) = try await mw.intercept(
            HTTPRequest(method: .post, scheme: "https", authority: "api.playerz.bg", path: "/bookings"),
            body: HTTPBody("payload"),
            baseURL: BASE,
            operationID: "createBooking"
        ) { req, body, url in
            await seen.set("\(req.method) \(req.path ?? "") \(url.absoluteString) body=\(body != nil)")
            return (HTTPResponse(status: .created), nil)
        }

        #expect(response.status == .created)
        #expect(await seen.value == "POST /bookings \(BASE.absoluteString) body=true")
    }
}
