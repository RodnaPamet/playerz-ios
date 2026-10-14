import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Everything in this target other than this file is GENERATED from
/// `openapi.json`, which is copied verbatim from the server repo's
/// `openapi/playerz-v1.json`.
///
/// A guardrail there (`tests/guardrails/openapi-coverage.test.ts`) fails the
/// server build if a v1 route exists without a matching path in the spec, or a
/// path exists without a route. So the set of ENDPOINTS here is trustworthy.
///
/// It is explicit that it does not check SCHEMAS — the DTOs are TypeScript
/// interfaces, not runtime values, so nothing compares them to the spec. Treat
/// generated request/response *shapes* as unverified until a round-trip test
/// exercises them against a running server.
public enum Playerz {
    /// Build a client against a base URL.
    ///
    /// `middlewares` is how auth is injected — see `BearerMiddleware`, which
    /// exists so the generated code never has to know about tokens.
    ///
    /// Typical use:
    ///
    ///     let store = TokenStore(persistence: keychain)
    ///     let client = Playerz.client(
    ///         baseURL: url,
    ///         middlewares: [BearerMiddleware(tokens: store, refresh: refresher)]
    ///     )
    /// `transport` is injectable so the session logic can be tested without a
    /// server. Production never passes it.
    public static func client(
        baseURL: URL,
        middlewares: [any ClientMiddleware] = [],
        transport: (any ClientTransport)? = nil
    ) -> Client {
        Client(
            serverURL: baseURL,
            configuration: Configuration(dateTranscoder: ServerDateTranscoder()),
            transport: transport ?? URLSessionTransport(),
            middlewares: middlewares
        )
    }
}

/// The server's dates, as it writes them.
///
/// Every date in a v1 response comes from JavaScript's `toISOString()`, which
/// always writes milliseconds: `2026-10-16T15:56:01.418Z`. The runtime's
/// default transcoder is plain ISO 8601 and rejects the fraction, so with it
/// every response that carries a date failed to decode, as a thrown
/// `DecodingError` the screens could only show as "failed". Real responses
/// captured from the server's routes found it (OpenPlayDecodingTests).
///
/// Decoding accepts both forms, so a date written without the fraction still
/// reads; encoding writes the fraction, which the server's validation accepts.
struct ServerDateTranscoder: DateTranscoder {
    func encode(_ date: Date) throws -> String {
        try ISO8601DateTranscoder.iso8601WithFractionalSeconds.encode(date)
    }

    func decode(_ string: String) throws -> Date {
        if let date = try? ISO8601DateTranscoder.iso8601WithFractionalSeconds.decode(string) {
            return date
        }
        return try ISO8601DateTranscoder.iso8601.decode(string)
    }
}
