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
    /// Which modules this server has on (#16); everything until it says.
    private(set) var modules: Modules = .unknown

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
        await refreshModules()
        // A DEBUG launch with credentials signs in as THEM (DebugLaunch): a
        // session kept from an earlier launch would otherwise win.
        if let debug = DebugLaunch.credentials {
            if state == .signedIn { await signOut() }
            await signIn(email: debug.email, password: debug.password)
        }
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
            // This phone's token, if notifications are allowed, now belongs to
            // this account (#12).
            await PushRegistrar.shared.refreshIfAllowed(self)
            await refreshModules()
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

    /// Delete the account (playerz-ios#9). On success the server has already
    /// ended every session, so this device is simply signed out.
    func deleteAccount() async -> AccountDeletion {
        guard let session else { return .failed }
        let outcome = await session.deleteAccount()
        if outcome == .deleted {
            // The server removed this account's devices with it.
            PushRegistrar.shared.signedOut()
            self.session = nil
            state = .signedOut
        }
        return outcome
    }

    /// The account's data, as the server's file (`GET /me/export`).
    func exportData() async throws -> Data {
        guard let session else { throw DataExportError.notSignedIn }
        return try await session.exportData()
    }

    /// The texts still to accept (#10).
    func owedTexts() async throws -> OwedTexts {
        guard let session else { throw LegalStepError.notSignedIn }
        return try await session.owedTexts()
    }

    /// Accept every text in force.
    func acceptTexts() async throws -> OwedTexts {
        guard let session else { throw LegalStepError.notSignedIn }
        return try await session.acceptTexts()
    }

    /// A legal text on the web (`/terms`, `/privacy`), where it is read.
    func legalTextURL(_ id: String) -> URL? {
        guard var parts = URLComponents(string: serverURL), parts.host != nil else { return nil }
        parts.path = "/\(id)"
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }

    /// The web's contact form, where a club account asks to be deleted
    /// (`CONTACT_FORM_HREF` on the server: the home page's clubs section).
    var contactFormURL: URL? {
        guard var parts = URLComponents(string: serverURL), parts.host != nil else { return nil }
        parts.path = "/"
        parts.query = nil
        parts.fragment = "clubs"
        return parts.url
    }

    /// Ask the server which modules are on. A failed read keeps what was known.
    func refreshModules() async {
        if let fresh = await session?.modules() { modules = fresh }
    }

    func signOut() async {
        // This phone's registration goes with the session (#12).
        try? await session?.signOut(unregistering: PushRegistrar.shared.deviceToken)
        PushRegistrar.shared.signedOut()
        session = nil
        state = .signedOut
    }

    /// An authenticated client, or nil when signed out.
    func client() async -> Client? {
        await session?.client()
    }
}
