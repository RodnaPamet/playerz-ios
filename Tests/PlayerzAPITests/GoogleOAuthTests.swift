import CryptoKit
import Foundation
import Testing

@testable import PlayerzAPI

private let CLIENT = "123456-abc.apps.googleusercontent.com"

@Suite("GoogleOAuth")
struct GoogleOAuthTests {
    private func flow() -> GoogleOAuth {
        GoogleOAuth(clientID: CLIENT, verifier: "verifier-0123456789-0123456789-0123456789", state: "st4te")!
    }

    @Test("only an iOS client ID builds a flow: no ID, no button")
    func clientIDShape() {
        #expect(GoogleOAuth(clientID: "") == nil)
        #expect(GoogleOAuth(clientID: ".apps.googleusercontent.com") == nil)
        #expect(GoogleOAuth(clientID: "abc.example.com") == nil)
        #expect(GoogleOAuth(clientID: "1-a b.apps.googleusercontent.com") == nil)
        #expect(GoogleOAuth(clientID: " \(CLIENT) ")?.clientID == CLIENT)
    }

    @Test("the redirect is the client ID reversed, as Google requires of an iOS client")
    func reversedScheme() {
        #expect(flow().callbackScheme == "com.googleusercontent.apps.123456-abc")
        #expect(flow().redirectURI == "com.googleusercontent.apps.123456-abc:/oauth2redirect")
    }

    @Test("the consent page asks for a code with PKCE S256 and the state")
    func authorizationURL() throws {
        let url = flow().authorizationURL
        #expect(url.host == "accounts.google.com")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(value("client_id") == CLIENT)
        #expect(value("response_type") == "code")
        #expect(value("scope") == "openid email profile")
        #expect(value("code_challenge_method") == "S256")
        #expect(value("state") == "st4te")
        #expect(value("redirect_uri") == "com.googleusercontent.apps.123456-abc:/oauth2redirect")
        // The verifier itself never leaves before the token request.
        #expect(!url.absoluteString.contains("verifier-0123"))
    }

    @Test("the challenge is RFC 7636's: SHA-256 of the verifier, base64url, unpadded")
    func challengeVector() {
        // RFC 7636 appendix B.
        let rfc = GoogleOAuth(
            clientID: CLIENT, verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", state: "s"
        )!
        #expect(rfc.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("a redirect yields its code only for this request's state")
    func callback() throws {
        let f = flow()
        let scheme = f.callbackScheme
        #expect(try f.code(from: URL(string: "\(scheme):/oauth2redirect?state=st4te&code=4/abc")!) == "4/abc")
        #expect(throws: GoogleOAuthError.badRedirect) {
            try f.code(from: URL(string: "\(scheme):/oauth2redirect?state=other&code=4/abc")!)
        }
        #expect(throws: GoogleOAuthError.badRedirect) {
            try f.code(from: URL(string: "evil:/oauth2redirect?state=st4te&code=4/abc")!)
        }
        #expect(throws: GoogleOAuthError.declined) {
            try f.code(from: URL(string: "\(scheme):/oauth2redirect?state=st4te&error=access_denied")!)
        }
        #expect(throws: GoogleOAuthError.badRedirect) {
            try f.code(from: URL(string: "\(scheme):/oauth2redirect?state=st4te")!)
        }
    }

    @Test("the token request carries the verifier and no secret")
    func tokenRequest() throws {
        let request = flow().tokenRequest(code: "4/a+b")
        #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
        #expect(request.httpMethod == "POST")
        let form = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(form.contains("grant_type=authorization_code"))
        #expect(form.contains("code=4%2Fa%2Bb"))
        #expect(form.contains("code_verifier=verifier-0123456789-0123456789-0123456789"))
        #expect(form.contains("redirect_uri=com.googleusercontent.apps.123456-abc%3A%2Foauth2redirect"))
        #expect(!form.contains("client_secret"))
    }

    @Test("the ID token is read from Google's answer; anything else is a refusal")
    func idToken() throws {
        #expect(try GoogleOAuth.idToken(from: Data(#"{"id_token":"h.p.s","access_token":"x"}"#.utf8), status: 200) == "h.p.s")
        #expect(throws: GoogleOAuthError.self) {
            try GoogleOAuth.idToken(from: Data(#"{"access_token":"x"}"#.utf8), status: 200)
        }
        #expect(throws: GoogleOAuthError.self) {
            try GoogleOAuth.idToken(from: Data(#"{"error":"invalid_grant"}"#.utf8), status: 400)
        }
    }

    @Test("random tokens are PKCE-length and differ")
    func randomTokens() {
        let a = GoogleOAuth.randomToken(), b = GoogleOAuth.randomToken()
        #expect(a.count == 43)
        #expect(a != b)
        #expect(a.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}
