import CryptoKit
import Foundation

/// Google sign-in for the app, without Google's SDK.
///
/// ═══ WHY NOT GoogleSignIn-iOS ═══
///
/// The server needs one thing from Google: an ID token whose `aud` is the
/// app's iOS OAuth client (`GOOGLE_IOS_CLIENT_ID`, projectZ
/// `verifyGoogleIdToken`). The SDK is one way to get it; the OAuth flow it
/// runs underneath is another, and that flow is a page in
/// `ASWebAuthenticationSession`, one POST, and PKCE. The SDK would add three
/// packages (AppAuth, GTMAppAuth, GTMSessionFetcher) to a project that has
/// none outside Apple's OpenAPI runtime, for what this file does.
///
/// ═══ THE FLOW ═══
///
/// 1. `authorizationURL`: Google's consent page, with a PKCE challenge and a
///    `state` that must come back unchanged.
/// 2. Google redirects to `redirectURI`, the client ID reversed: the scheme an
///    iOS-type client is allowed to redirect to. `ASWebAuthenticationSession`
///    catches it by `callbackScheme`; nothing is registered in Info.plist.
/// 3. `code(from:)` takes the code out of that redirect.
/// 4. `tokenRequest(code:)` trades it for tokens. An iOS client has no secret:
///    the PKCE verifier is what proves this is the app that started step 1.
/// 5. `idToken(from:status:)` reads the ID token out of the answer, and that
///    is what `PlayerzSession.signIn(googleIDToken:)` sends to the server.
///
/// Pure values and requests, no networking or UI, so the whole flow is tested
/// without a browser.
public struct GoogleOAuth: Sendable {
    public let clientID: String
    /// The PKCE secret: kept here, sent only with the token request.
    let verifier: String
    let state: String

    static let authorizeEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    /// Nil unless `clientID` is an iOS client's: `<project>-<id>.apps.googleusercontent.com`.
    /// A build without one (every build until the owner supplies it) offers no
    /// Google button rather than a broken one.
    public init?(clientID: String, verifier: String = Self.randomToken(), state: String = Self.randomToken()) {
        let suffix = ".apps.googleusercontent.com"
        let id = clientID.trimmingCharacters(in: .whitespaces)
        guard id.hasSuffix(suffix), id.count > suffix.count,
              id.dropLast(suffix.count).allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" })
        else { return nil }
        self.clientID = id
        self.verifier = verifier
        self.state = state
    }

    /// `com.googleusercontent.apps.<id>`: the client ID reversed.
    public var callbackScheme: String {
        "com.googleusercontent.apps." + clientID.dropLast(".apps.googleusercontent.com".count)
    }

    var redirectURI: String { callbackScheme + ":/oauth2redirect" }

    /// PKCE S256: the verifier's SHA-256, base64url without padding.
    var challenge: String {
        Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// Google's page, asking for the account's identity and address: the
    /// server finds accounts by a verified email (`EMAIL_REQUIRED`).
    public var authorizationURL: URL {
        var parts = URLComponents(url: Self.authorizeEndpoint, resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            // Every time, the account picker: the sign-in sheet keeps no
            // cookies, and a second Google account is the commonest reason
            // to be signing in again.
            .init(name: "prompt", value: "select_account"),
        ]
        return parts.url!
    }

    /// The code from Google's redirect, once it is known to answer THIS request.
    public func code(from callback: URL) throws(GoogleOAuthError) -> String {
        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              callback.scheme == callbackScheme
        else { throw .badRedirect }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        // A state that is not ours is a redirect somebody else started: its
        // code must not be traded in for this app's session.
        guard value("state") == state else { throw .badRedirect }
        if let error = value("error") {
            throw error == "access_denied" ? .declined : .refused(error)
        }
        guard let code = value("code"), !code.isEmpty else { throw .badRedirect }
        return code
    }

    /// The code traded for tokens: a form POST with the PKCE verifier.
    public func tokenRequest(code: String) -> URLRequest {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", clientID),
            ("redirect_uri", redirectURI),
            ("code_verifier", verifier),
        ]
        request.httpBody = Data(form.map { "\($0)=\(Self.formEncoded($1))" }.joined(separator: "&").utf8)
        return request
    }

    /// The ID token in Google's answer to `tokenRequest`.
    public static func idToken(from data: Data, status: Int) throws(GoogleOAuthError) -> String {
        struct Answer: Decodable { let id_token: String? }
        guard status == 200 else { throw .refused("token \(status)") }
        guard let token = (try? JSONDecoder().decode(Answer.self, from: data))?.id_token, !token.isEmpty
        else { throw .refused("no id_token") }
        return token
    }

    /// 32 random bytes, base64url: 43 characters, inside PKCE's 43…128.
    public static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return base64URL(Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// `application/x-www-form-urlencoded`: everything but the unreserved set.
    static func formEncoded(_ value: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public enum GoogleOAuthError: Error, Equatable {
    /// The person closed Google's page or said no: nothing to report.
    case declined
    /// A redirect that is not an answer to this request.
    case badRedirect
    /// Google refused, with its reason (for the log, not the screen).
    case refused(String)
}
