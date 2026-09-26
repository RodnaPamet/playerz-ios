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
    public static func client(
        baseURL: URL,
        middlewares: [any ClientMiddleware] = []
    ) -> Client {
        Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: middlewares
        )
    }
}
