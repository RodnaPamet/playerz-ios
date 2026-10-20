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
    /// An invite link opened in the app (#14), shown once signed in; kept
    /// across signing in, as the web returns to the invite after its sign-in.
    var pendingInvite: PendingInvite? = DebugLaunch.invite.map(PendingInvite.init(token:))
    /// The bell's count (#15), read every minute by RootView and set to what
    /// the server answers when the list marks everything read.
    var notificationsUnread = 0
    /// The bell's list, open over the tabs.
    var notificationsOpen = DebugLaunch.notifications
    /// A screen to open over the tabs: a tapped push (#15).
    var pendingLink: AppLink? = DebugLaunch.link.flatMap(AppLink.init(path:))
    /// A tab a link asked for; RootView switches to it.
    var requestedTab: DebugLaunch.Tab?

    /// Raised when an action was refused for want of a confirmed phone
    /// (`PHONE_REQUIRED`, #11): RootView opens the phone step over the screen.
    var phoneStepNeeded = false

    private var session: PlayerzSession?

    /// Whether `link` is a whole tab rather than one screen.
    func isTab(_ link: AppLink) -> Bool {
        switch link {
        case .bookings, .messages, .games: true
        case .booking, .conversation: false
        }
    }

    /// Open `link`: a tab is switched to, a screen opened over the tabs. A
    /// module the server has off opens nothing (#16).
    func open(_ link: AppLink) {
        switch link {
        case .bookings: requestedTab = .bookings
        case .messages: if modules.messaging { requestedTab = .messages }
        case .games: if modules.openPlay { requestedTab = .games }
        case .conversation: if modules.messaging { pendingLink = link }
        case .booking: pendingLink = link
        }
    }

    /// The bell's count: the first page's `unreadCount`. A failed read keeps
    /// the count it had.
    func refreshNotificationCount() async {
        guard let client = await client(),
              let page = try? await client.listMyNotifications(query: .init(limit: 1)).ok.body.json.data
        else { return }
        notificationsUnread = page.unreadCount
    }

    /// A link the app was opened with. Answers whether it was one of ours.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let token = BookingInviteLink.token(in: url) else { return false }
        pendingInvite = PendingInvite(token: token)
        return true
    }

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
    /// Whether the account may be deleted now (projectZ#628); nil if unknown.
    func deletionCheck() async -> DeletionCheck? {
        await session?.deletionCheck()
    }

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

    /// The account's language follows the app's (#13): written when they
    /// differ, at launch and after signing in. Changing the app's language in
    /// iOS Settings relaunches it, so this sees every change.
    func followLanguage(of me: Components.Schemas.Me) async {
        let code = AppLanguage.code(for: Bundle.main.preferredLocalizations.first)
        guard me.locale != code.rawValue, let session else { return }
        _ = await session.saveLanguage(code)
    }

    /// A refusal from any screen: one that needs the phone step opens it.
    func notice(refusal code: String?) {
        if code == "PHONE_REQUIRED" { phoneStepNeeded = true }
    }

    /// The phone step (#11).
    func startPhone(_ number: String) async throws -> PhoneCode {
        guard let session else { throw PhoneStepError.notSignedIn }
        return try await session.startPhone(number)
    }

    func confirmPhone(_ number: String, code: String, challenge: String) async throws {
        guard let session else { throw PhoneStepError.notSignedIn }
        try await session.confirmPhone(number, code: code, challenge: challenge)
        phoneStepNeeded = false
    }

    /// «Не сега», remembered per account on this phone, as the web remembers
    /// it per browser: the step is offered once, then only when an action
    /// needs it.
    func wasAskedForPhone(_ userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: "phone.asked.\(userId)")
    }

    func rememberAskedForPhone(_ userId: String) {
        UserDefaults.standard.set(true, forKey: "phone.asked.\(userId)")
    }

    /// A step of the booking funnel, for the club's counts (#17). Never waited
    /// on by a screen: a count must not slow a booking.
    func send(_ event: UsageBeacon, venueId: String) {
        guard let session else { return }
        Task { await session.send(event, venueId: venueId) }
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
