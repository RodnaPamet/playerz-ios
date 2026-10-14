import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Sends one fixed access token. For the one request that must carry a token
/// the session no longer holds: the logout after the Keychain was cleared
/// (`PlayerzSession.signOut`, playerz-ios#1).
struct StaticBearerMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var authorised = request
        authorised.headerFields[.authorization] = "Bearer \(token)"
        return try await next(authorised, body, baseURL)
    }
}
