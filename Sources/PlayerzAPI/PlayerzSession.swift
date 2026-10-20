import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

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
        // The password grant: test runs only on the server (#361). The app's
        // real ways in are the provider grants (projectZ #444, #442).
        let response = try await anonymous.authSignIn(
            .init(body: .json(.AuthTokenPasswordRequest(.init(email: email, password: password))))
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

    /// Sign out of this device. `deviceToken` is this phone's APNs token, if
    /// it has one: its registration is removed first, with the session that
    /// owns it, so the next person to use the phone does not receive this
    /// account's notifications (playerz-ios#12). The server's logout leaves
    /// devices alone, so nothing else would.
    public func signOut(unregistering deviceToken: String? = nil) async throws {
        // The server ends the session the ACCESS token names, and an
        // anonymous or expired one names nothing (projectZ's logout route).
        // So take a live one first, refreshing only if it has expired. A
        // failure here must not stand in the way of the local sign-out.
        let presented = try? await tokens.validAccessToken(refreshing: makeRefresher())

        // Local first. If the network call fails the user still expects to be
        // signed out of THIS device, and a token left in the Keychain is the
        // one thing they cannot fix themselves.
        try await tokens.signOut()

        guard let presented else { return }
        // Then the server, with the token captured above: the Keychain no
        // longer holds it, so the session's own middleware has nothing to send.
        let bearer = Playerz.client(
            baseURL: baseURL,
            middlewares: [StaticBearerMiddleware(token: presented)],
            transport: transport
        )
        // Before the logout: the registration is the account's, and once the
        // session is gone nothing on this phone may remove it. Best effort, as
        // the logout is: offline, the next sign-in here re-registers the token
        // to whoever signs in, which moves it off this account.
        if let deviceToken {
            _ = try? await bearer.unregisterDevice(.init(query: .init(deviceToken: deviceToken)))
        }
        _ = try? await bearer.authLogout(.init(body: .json(.init())))
    }

    /// Delete the account (`DELETE /me`, playerz-ios#9).
    ///
    /// On success the server has already ended every session of the account,
    /// this one included, so there is nobody left to log out: only the
    /// Keychain is cleared. A refusal changes nothing, here or there.
    public func deleteAccount() async -> AccountDeletion {
        let response: Operations.deleteMe.Output
        do {
            response = try await client().deleteMe()
        } catch {
            return .failed
        }
        switch response {
        case .noContent:
            try? await tokens.signOut()
            return .deleted
        case let .conflict(conflict):
            guard let error = try? conflict.body.json.error, error.code == "UPCOMING_BOOKINGS",
                let details = error.details,
                let standing = UpcomingStanding(details.additionalProperties)
            else { return .failed }
            return .blocked(standing)
        case let .forbidden(forbidden):
            let code = try? forbidden.body.json.error.code
            return code == "CLUB_ACCOUNT_DELETION_BY_REQUEST" ? .clubAccount : .failed
        case .tooManyRequests:
            return .rateLimited
        default:
            return .failed
        }
    }

    /// The account's personal data (`GET /me/export`) exactly as the server
    /// wrote it: the bytes of the file, for the share sheet.
    ///
    /// Not through the generated `exportMyData`, which would decode the
    /// document into the spec's types and lose any field the spec does not
    /// name. An export that silently leaves something out is the one kind
    /// that must not happen, so this asks the same transport for the raw body,
    /// with the session's token.
    public func exportData() async throws -> Data {
        guard let token = try await tokens.validAccessToken(refreshing: makeRefresher()) else {
            throw DataExportError.notSignedIn
        }
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/me/export")
        request.headerFields[.authorization] = "Bearer \(token)"
        request.headerFields[.accept] = "application/json"
        let (response, body) = try await (transport ?? URLSessionTransport()).send(
            request, body: nil, baseURL: baseURL, operationID: "exportMyData"
        )
        switch response.status.code {
        case 200:
            guard let body else { throw DataExportError.refused(200) }
            // The export is a few hundred kilobytes for a busy account; the
            // ceiling only guards against a runaway body.
            return try await Data(collecting: body, upTo: 50 * 1024 * 1024)
        case 401:
            throw DataExportError.notSignedIn
        case 429:
            throw DataExportError.rateLimited
        default:
            throw DataExportError.refused(response.status.code)
        }
    }

    /// The texts this account still has to accept (playerz-ios#10).
    public func owedTexts() async throws -> OwedTexts {
        let response: Operations.getLegalStanding.Output
        do {
            response = try await client().getLegalStanding()
        } catch {
            throw LegalStepError.failed
        }
        switch response {
        case let .ok(ok):
            // A text the spec does not know yet fails to decode: say "failed",
            // and let the caller decide; it must not read as "nothing owed".
            guard let standing = try? ok.body.json.data else { throw LegalStepError.failed }
            return OwedTexts(standing)
        case .unauthorized:
            throw LegalStepError.notSignedIn
        default:
            throw LegalStepError.failed
        }
    }

    /// Accept every text in force, at its current version. Answers what is
    /// still owed afterwards, which is nothing.
    public func acceptTexts() async throws -> OwedTexts {
        let response: Operations.acceptLegal.Output
        do {
            response = try await client().acceptLegal()
        } catch {
            throw LegalStepError.failed
        }
        switch response {
        case let .ok(ok):
            guard let standing = try? ok.body.json.data else { throw LegalStepError.failed }
            return OwedTexts(standing)
        case .unauthorized:
            throw LegalStepError.notSignedIn
        case .tooManyRequests:
            throw LegalStepError.rateLimited
        default:
            throw LegalStepError.failed
        }
    }

    /// The module switches (playerz-ios#16). Public, so asked without the
    /// session; nil when the server could not be asked or answered something
    /// else, and the caller keeps what it knew.
    public func modules() async -> Modules? {
        guard let response = try? await anonymous.getAppConfig(),
            case let .ok(ok) = response,
            let data = try? ok.body.json.data
        else { return nil }
        return Modules(data.modules)
    }

    /// The phone step, part one (playerz-ios#11): send a code to `number`, as
    /// typed (`0888 123 456`); the server normalises it.
    public func startPhone(_ number: String) async throws -> PhoneCode {
        let response: Operations.startPhoneVerification.Output
        do {
            response = try await client().startPhoneVerification(body: .json(.init(phone: number)))
        } catch {
            throw PhoneStepError.failed
        }
        switch response {
        case let .ok(ok):
            guard let sent = try? ok.body.json.data else { throw PhoneStepError.failed }
            return PhoneCode(maskedNumber: sent.number, challenge: sent.challenge)
        case let .badRequest(refused):
            throw (try? refused.body.json.error.code) == "PHONE_INVALID" ? PhoneStepError.invalidNumber : .failed
        case .unauthorized: throw PhoneStepError.notSignedIn
        case .tooManyRequests: throw PhoneStepError.rateLimited
        case .serviceUnavailable: throw PhoneStepError.unavailable
        default: throw PhoneStepError.failed
        }
    }

    /// The phone step, part two: the code from the SMS, for the same number and
    /// the challenge part one answered. On success the number is the account's.
    public func confirmPhone(_ number: String, code: String, challenge: String) async throws {
        let response: Operations.confirmPhoneVerification.Output
        do {
            response = try await client().confirmPhoneVerification(
                body: .json(.init(phone: number, code: code, challenge: challenge))
            )
        } catch {
            throw PhoneStepError.failed
        }
        switch response {
        case .ok: return
        case let .badRequest(refused):
            switch try? refused.body.json.error.code {
            case "PHONE_CODE_WRONG": throw PhoneStepError.wrongCode
            case "PHONE_CODE_EXPIRED": throw PhoneStepError.expiredCode
            case "PHONE_INVALID": throw PhoneStepError.invalidNumber
            default: throw PhoneStepError.failed
            }
        case .conflict: throw PhoneStepError.numberInUse
        case .unauthorized: throw PhoneStepError.notSignedIn
        case .tooManyRequests: throw PhoneStepError.rateLimited
        case .serviceUnavailable: throw PhoneStepError.unavailable
        default: throw PhoneStepError.failed
        }
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
