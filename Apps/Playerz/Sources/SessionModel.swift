import Foundation
import Observation
import PlayerzAPI

/// The app's view of the session.
///
/// A thin shell over `PlayerzSession`, which is where the decisions live. This
/// exists to give SwiftUI something observable and to turn thrown errors into
/// a message the screen can show.
@MainActor
@Observable
final class SessionModel {
    enum State { case unknown, signedOut, signedIn }

    /// The dev server, reachable from the device or simulator.
    ///
    /// Editable on the sign-in screen rather than baked in: a cloudflared quick
    /// tunnel gets a fresh hostname every run, so a hardcoded value only ever
    /// ships a dead URL.
    ///
    /// `PLAYERZ_SERVER_URL` pre-fills it, which is how a simulator or CI run
    /// avoids typing one in:
    ///
    ///     SIMCTL_CHILD_PLAYERZ_SERVER_URL=https://… xcrun simctl launch booted bg.playerz.app
    ///
    /// Reading an environment variable is inert in a shipped build — nothing
    /// sets it — so this needs no #if and cannot change release behaviour.
    var serverURL: String = ProcessInfo.processInfo.environment["PLAYERZ_SERVER_URL"] ?? ""
    private(set) var state: State = .unknown
    private(set) var signInError: String?
    private(set) var busy = false

    private var session: PlayerzSession?

    /// Restore a session from the Keychain, if the URL is already known.
    func restore() async {
        guard let url = URL(string: serverURL), !serverURL.isEmpty else {
            state = .signedOut
            return
        }
        let s = PlayerzSession(baseURL: url)
        session = s
        state = await s.isSignedIn ? .signedIn : .signedOut
    }

    func signIn(email: String, password: String) async {
        guard let url = URL(string: serverURL), url.scheme != nil else {
            signInError = String(localized: "signIn.failed")
            return
        }

        busy = true
        signInError = nil
        defer { busy = false }

        let s = PlayerzSession(baseURL: url)
        do {
            try await s.signIn(email: email, password: password)
            session = s
            state = .signedIn
        } catch SessionError.invalidCredentials {
            // One message for both "no such account" and "wrong password".
            // `authorize()` equalises bcrypt timing precisely so the response
            // cannot enumerate accounts; distinguishing them here would undo it.
            signInError = String(localized: "signIn.invalid")
        } catch SessionError.throttled {
            signInError = String(localized: "signIn.throttled")
        } catch {
            signInError = String(localized: "signIn.failed")
        }
    }

    func signOut() async {
        try? await session?.signOut()
        session = nil
        state = .signedOut
    }

    /// An authenticated client, or nil when signed out.
    func client() async -> Client? {
        await session?.client()
    }
}
