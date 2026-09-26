import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Attaches the session's access token to every authenticated request.
///
/// Exists so the generated code never has to know about tokens: an operation
/// is called the same way whether or not it needs auth, and the refresh that
/// may happen first is invisible to the call site.
public struct BearerMiddleware: ClientMiddleware {
    private let tokens: TokenStore
    private let refresh: @Sendable (String) async throws -> Tokens

    /// The operations that must NOT carry a bearer token.
    ///
    /// `authRefresh` above all: it is what `refresh` calls, so attaching a
    /// token to it means `validAccessToken` is re-entered while already
    /// refreshing. `authSignIn` has no session yet by definition, and sending a
    /// stale token with a password would be a confusing thing for the server
    /// to receive.
    ///
    /// Operation IDs, not paths, because the generated client passes the
    /// `operationId` from the spec — and a ratchet in the server repo now
    /// requires every operation to have a unique one.
    private static let unauthenticated: Set<String> = [
        "authSignIn",
        "authRefresh",
        // Public discovery: these work signed out, and sending a token would
        // only widen what a logged-out browse can be correlated with.
        "listVenues",
        "findVenuesNear",
        "getVenue",
        "getVenueAvailability",
    ]

    public init(
        tokens: TokenStore,
        refresh: @escaping @Sendable (String) async throws -> Tokens
    ) {
        self.tokens = tokens
        self.refresh = refresh
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !Self.unauthenticated.contains(operationID) else {
            return try await next(request, body, baseURL)
        }

        var authorised = request
        if let token = try await tokens.validAccessToken(refreshing: refresh) {
            authorised.headerFields[.authorization] = "Bearer \(token)"
        }
        // No token means signed out. The request still goes, and the server
        // answers 401 — which is the honest outcome, and lets a screen that
        // does not need auth keep working instead of throwing here.

        return try await next(authorised, body, baseURL)
    }
}

// ═══ WHY THERE IS NO RETRY-ON-401 ═══
//
// The obvious addition is: on a 401, refresh and replay the request. It is
// deliberately absent.
//
// `HTTPBody` is a stream, and it is consumed by the first attempt. Replaying a
// request whose body has already been read sends an EMPTY body to the same
// endpoint — so a booking POST that met an expired token would retry as a
// booking POST with no payload, and the failure would be a confusing 400 rather
// than the 401 it started as. Making it safe means buffering every request body
// in memory on the chance it is needed, which is a real cost paid on every
// call for a case that should not arise.
//
// It should not arise because `TokenStore.validAccessToken` refreshes
// PROACTIVELY, treating a token with less than 60 seconds of life as already
// expired. A 401 therefore means the session is genuinely gone — revoked,
// signed out elsewhere, or past the refresh window — and no retry would help.
//
// If this ever needs to change, the honest version buffers the body only for
// operations known to be idempotent, rather than pretending a stream can be
// rewound.
