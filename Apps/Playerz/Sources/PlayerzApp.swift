import PlayerzAPI
import SwiftUI
import UserNotifications

@main
struct PlayerzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var session = SessionModel()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                // A refusal for want of a confirmed phone, from any screen (#11).
                .sheet(isPresented: $session.phoneStepNeeded) {
                    PhoneStepView(session: session) {
                        session.phoneStepNeeded = false
                    } later: {
                        session.phoneStepNeeded = false
                    }
                }
                // An invite link (#14). Universal links are the release's
                // (#24); until then this is reached by a DEBUG launch.
                .onOpenURL { session.open($0) }
                .task {
                    // A tapped push opens its screen (#15), also one that launched the app.
                    delegate.onLink { session.open($0) }
                    await session.restore()
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
    /// Unread conversations and requests, for the Съобщения tab's badge.
    @State private var unread = 0
    @State private var tab: DebugLaunch.Tab = DebugLaunch.tab ?? .play

    var body: some View {
        Group {
            switch session.state {
            case .unknown:
                ProgressView().controlSize(.large)
            case .signedOut:
                SignInView(session: session)
            case .signedIn:
                // The player's tabs, as the web's bottom bar (#362): Играй, Игри (#510),
                // Резервации; then Съобщения, which the web keeps in its header, and Профил.
                // `.tabItem`, not `Tab`: the app supports iOS 17, and `Tab` is 18.
                // Where this account lands first (#167): a club account and an
                // undecided one do not get the player's tabs.
                LandingGate(session: session) {
                    TabView(selection: $tab) {
                        VenueListView(session: session)
                            .tabItem { Label(String(localized: "tab.play"), systemImage: "figure.tennis") }
                            .tag(DebugLaunch.Tab.play)
                        // A module the server has off is not shown at all (#16).
                        if session.modules.openPlay {
                            GamesView(session: session)
                                .tabItem { Label(String(localized: "tab.games"), systemImage: "person.3") }
                                .tag(DebugLaunch.Tab.games)
                        }
                        MyBookingsView(session: session)
                            .tabItem { Label(String(localized: "tab.bookings"), systemImage: "calendar") }
                            .tag(DebugLaunch.Tab.bookings)
                        if session.modules.messaging {
                            InboxView(session: session, unread: $unread)
                                .tabItem { Label(String(localized: "tab.messages"), systemImage: "bubble.left.and.bubble.right") }
                                .badge(unread)
                                .tag(DebugLaunch.Tab.messages)
                        }
                        ProfileView(session: session)
                            .tabItem { Label(String(localized: "tab.profile"), systemImage: "person.crop.circle") }
                            .tag(DebugLaunch.Tab.profile)
                    }
                    // The badge without opening the tab: read on launch, then each
                    // minute, and only while messaging is on.
                    .task(id: session.modules.messaging) {
                        while !Task.isCancelled, session.modules.messaging {
                            if let client = await session.client(),
                               let counts = try? await client.getMyUnreadConversations().ok.body.json.data {
                                unread = counts.conversations + counts.requests
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
                    .sheet(isPresented: $session.notificationsOpen) {
                        NotificationsView(session: session)
                    }
                    // A tapped push's screen (#15).
                    .sheet(item: $session.pendingLink) { link in
                        LinkedSheet(link: link, session: session)
                    }
                }
            }
        }
        // The switches can change while the app is open: read them again
        // whenever it comes back (#16).
        .task(id: scenePhase) {
            if scenePhase == .active { await session.refreshModules() }
        }
        // A link that names a tab (#15): the bell's row or a tapped push.
        .onChange(of: session.requestedTab) { _, requested in
            guard let requested else { return }
            tab = requested
            session.requestedTab = nil
        }
        .onChange(of: session.modules) { _, modules in
            if (tab == .games && !modules.openPlay) || (tab == .messages && !modules.messaging) {
                tab = .play
            }
        }
    }
}
