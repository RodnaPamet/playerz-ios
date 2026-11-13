import PlayerzAPI
import SwiftUI
import UserNotifications

@main
struct PlayerzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var session: SessionModel

    init() {
        // Before the first text is looked up (AppLanguageChoice).
        AppLanguageChoice.applyAtLaunch()
        _session = State(initialValue: SessionModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                // Dates, amounts and SwiftUI's own words in the app's language.
                .environment(\.locale, AppLanguageChoice.locale(session.language))
                // A refusal for want of a confirmed phone, from any screen (#11).
                .sheet(isPresented: $session.phoneStepNeeded) {
                    PhoneStepView(session: session) {
                        session.phoneStepNeeded = false
                    } later: {
                        session.phoneStepNeeded = false
                    }
                }
                // An invite link (#14), tapped anywhere: a universal link
                // (#24) lands here too.
                .onOpenURL { session.open($0) }
                .task {
                    // A tapped push opens its screen (#15), also one that launched the app.
                    delegate.onLink { session.open($0) }
                    await session.restore()
                    // DEBUG only: the picker's choice, made without a tap.
                    if let code = DebugLaunch.chooseLanguage {
                        try? await Task.sleep(for: .seconds(3))
                        await session.chooseLanguage(AppLanguage.code(for: code))
                    }
                    if session.state == .signedIn { await PushRegistrar.shared.refreshIfAllowed(session) }
                }
        }
    }
}

/// APNs registration is a UIApplicationDelegate callback and has no async
/// alternative, so the delegate exists to forward the token and to make sure a
/// notification arriving while the app is OPEN is actually shown.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// A push tapped before the app could take it: the tap that launched it.
    private var tappedLink: AppLink?
    private var openLink: ((AppLink) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Alerts and dialogs are UIKit's and do not read SwiftUI's tint.
        UIWindow.appearance().tintColor = UIColor(Theme.Palette.accentText)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushRegistrar.shared.tokenArrived(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Usually a provisioning profile with no aps-environment. Nothing the
        // user can act on, and push is an enhancement — so it stays quiet.
    }

    /// iOS does NOT show a banner for the app that is in the FOREGROUND unless
    /// the app says so. Without this, a delivered notification looks exactly
    /// like a lost one — which is what happened while proving #166.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// A tapped push (#15): the server puts the notification's web path in
    /// `url`, and the app opens the same screen the bell's row would.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let path = response.notification.request.content.userInfo["url"] as? String
        guard let link = path.flatMap(AppLink.init(path:)) else { return }
        await tapped(link)
    }

    /// Where tapped pushes go from now on; one already tapped goes there now.
    func onLink(_ open: @escaping (AppLink) -> Void) {
        openLink = open
        if let link = tappedLink {
            tappedLink = nil
            open(link)
        }
    }

    private func tapped(_ link: AppLink) {
        if let openLink { openLink(link) } else { tappedLink = link }
    }
}

/// Which screen the app is on, derived from whether a session exists.
///
/// Deliberately not a navigation stack decision: signing out must return to the
/// sign-in screen from anywhere, and a stack makes that a pop from an unknown
/// depth. Root swaps instead.
struct RootView: View {
    @Bindable var session: SessionModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: DebugLaunch.Tab = RootView.firstTab

    /// `PLAYERZ_TAB=messages` opens the inbox over «Начало» (SessionModel.messagesOpen).
    private static var firstTab: DebugLaunch.Tab {
        guard let tab = DebugLaunch.tab, tab != .messages else { return .play }
        return tab
    }

    var body: some View {
        Group {
            switch session.state {
            case .unknown:
                ProgressView().controlSize(.large)
            case .signedOut:
                SignInView(session: session)
            case .signedIn:
                // The player's tabs (PlayerShell): Начало, Открий (#510), Резервации,
                // Профил; Съобщения is in the header, where the web keeps it (#362).
                // Where this account lands first (#167): a club account and an
                // undecided one do not get the player's tabs.
                LandingGate(session: session) {
                    PlayerShell(session: session, tab: $tab)
                        // Every text is read again in a newly chosen language;
                        // the tab stays (it is RootView's).
                        .id(session.language)
                        // The dot without opening the inbox: read on launch, then each
                        // minute, and only while messaging is on.
                        .task(id: session.modules.messaging) {
                            while !Task.isCancelled, session.modules.messaging {
                                if let client = await session.client(),
                                   let counts = try? await client.getMyUnreadConversations().ok.body.json.data {
                                    session.messagesUnread = counts.conversations + counts.requests
                                }
                                try? await Task.sleep(for: .seconds(60))
                            }
                        }
                        // The bell's count (#15): read on launch, then each minute.
                        .task {
                            while !Task.isCancelled {
                                await session.refreshNotificationCount()
                                try? await Task.sleep(for: .seconds(60))
                            }
                        }
                        // An invite link opened in the app (#14), once past the gate's steps.
                        .sheet(item: $session.pendingInvite) { invite in
                            BookingInviteView(token: invite.token, session: session)
                        }
                        // The bell's list (#15), one for every tab's bell.
                        // A page under the header band with a back button, as the
                        // inbox is, not a card.
                        .fullScreenCover(isPresented: $session.notificationsOpen) {
                            // A push tapped while it was open (#56): its screen, now that it can rise.
                            if let link = session.linkAfterNotifications {
                                session.linkAfterNotifications = nil
                                session.pendingLink = link
                            }
                            if let invite = session.inviteAfterNotifications {
                                session.inviteAfterNotifications = nil
                                session.pendingInvite = invite
                            }
                        } content: {
                            NotificationsView(session: session)
                        }
                        // A tapped push's screen (#15).
                        .sheet(item: $session.pendingLink) { link in
                            LinkedSheet(link: link, session: session)
                        }
                }
            }
        }
        // The accent for text-like controls (links, plain buttons). Fills take
        // a fill token instead: white on this tint's dark value is 2.2:1.
        .tint(Theme.Palette.accentText)
        // The switches can change while the app is open: read them again
        // whenever it comes back (#16).
        .task(id: scenePhase) {
            if scenePhase == .active { await session.refreshModules() }
        }
        // A link that names a tab (#15): the bell's row or a tapped push.
        .onChange(of: session.requestedTab) { _, requested in
            guard let requested else { return }
            session.requestedTab = nil
            // A tab asked for while «Известия» is open: the list closes, or the
            // switch happens under it, unseen (#56).
            session.notificationsOpen = false
            if requested == .messages {
                // A layer of the shell, so a sheet still closing does not stop it.
                session.messagesOpen = true
            } else {
                tab = requested
                session.messagesOpen = false
            }
        }
        .onChange(of: session.modules) { _, modules in
            if tab == .games && !modules.openPlay { tab = .play }
            if !modules.messaging { session.messagesOpen = false }
        }
    }
}
