import Foundation
import OpenAPIRuntime

/// Owns the session and hands out a client that carries it.
///
/// ═══ WHY THIS IS IN THE PACKAGE AND NOT THE APP ═══
///
/// Everything here is decidable without a screen: what a sign-in response means,
/// which client a caller gets, what happens to a refresh token that comes back
/// null. Put it in a view model and it can only be exercised by driving a UI.
///
/// The app holds one of these and asks it for `client()`.
public actor PlayerzSession {
    private let baseURL: URL
    private let tokens: TokenStore

    /// Unauthenticated, and used for exactly two things: signing in, and
    /// refreshing. Both are exempt from `BearerMiddleware` anyway — sending a
    /// token to `authRefresh` re-enters the refresh it is part of.
    private let anonymous: Client

    private let transport: (any ClientTransport)?

    /// `transport` is for tests. Production leaves it nil and gets URLSession.
    public init(
        baseURL: URL,
        persistence: any TokenPersistence = KeychainTokenPersistence(),
        transport: (any ClientTransport)? = nil
    ) {
        // The generated client's paths are relative to the /api/v1 root.
        let api = baseURL.appendingPathComponent("api/v1")
        self.baseURL = api
        self.tokens = TokenStore(persistence: persistence)
        self.transport = transport
        self.anonymous = Playerz.client(baseURL: api, transport: transport)
    }

    public var isSignedIn: Bool {
        get async { await tokens.current != nil }
    }

    /// A client that attaches the session, refreshing first if it must.
    ///
    /// Built per call rather than stored: it is a cheap value, and caching one
    /// would outlive a sign-out that replaced the session underneath it.
    public func client() -> Client {
        Playerz.client(
            baseURL: baseURL,
            middlewares: [BearerMiddleware(tokens: tokens, refresh: makeRefresher())],
            transport: transport
        )
    }

    public func signIn(email: String, password: String) async throws {
        let response = try await anonymous.authSignIn(
            .init(body: .json(.init(email: email, password: password)))
        )

        switch response {
        case let .ok(ok):
            let data = try ok.body.json.data
            guard let refresh = data.refreshToken else {
                // The server only omits this on a REFRESH inside the rotation
                // grace window. A sign-in without one leaves a session that
                // cannot outlive its 15-minute access token, which is worse
                // than failing here where it can be reported.
                throw SessionError.noRefreshToken
            }
            try await tokens.set(
                Tokens(
                    accessToken: data.accessToken,
                    accessExpiresAt: data.expiresAt,
                    refreshToken: refresh,
                    refreshExpiresAt: data.refreshExpiresAt
                )
            )
        case .unauthorized:
            throw SessionError.invalidCredentials
        case .tooManyRequests:
            throw SessionError.throttled
        default:
            throw SessionError.unexpected(String(describing: response))
        }
    }

    public func signOut() async throws {
        // Local first. If the network call fails the user still expects to be
        // signed out of THIS device, and a token left in the Keychain is the
        // one thing they cannot fix themselves.
        try await tokens.signOut()
        _ = try? await anonymous.authLogout(.init(body: .json(.init())))
    }

    /// Exchange a refresh token for a new session.
    ///
    /// Isolated as a `@Sendable` closure because `BearerMiddleware` holds it
    /// across actor boundaries.
    private func makeRefresher() -> @Sendable (String) async throws -> Tokens {
        let anonymous = self.anonymous
        return { presented in
            let response = try await anonymous.authRefresh(
                .init(body: .json(.init(refreshToken: presented)))
            )
            guard case let .ok(ok) = response else {
                throw SessionError.refreshRejected
            }
            let data = try ok.body.json.data
            return Tokens(
                accessToken: data.accessToken,
                accessExpiresAt: data.expiresAt,
                // Null means KEEP the one we presented — see TokenStore.
                refreshToken: data.refreshToken ?? presented,
                refreshExpiresAt: data.refreshExpiresAt
            )
        }
    }
}

public enum SessionError: Error, Equatable {
    case invalidCredentials
    case throttled
    case noRefreshToken
    case refreshRejected
    case unexpected(String)
}
