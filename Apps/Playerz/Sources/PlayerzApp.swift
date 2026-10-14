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
                .task { await session.restore() }
        }
    }
}

/// APNs registration is a UIApplicationDelegate callback and has no async
/// alternative, so the delegate exists to forward the token and to make sure a
/// notification arriving while the app is OPEN is actually shown.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
}

/// Which screen the app is on, derived from whether a session exists.
///
/// Deliberately not a navigation stack decision: signing out must return to the
/// sign-in screen from anywhere, and a stack makes that a pop from an unknown
/// depth. Root swaps instead.
struct RootView: View {
    @Bindable var session: SessionModel
    /// Unread conversations and requests, for the Съобщения tab's badge.
    @State private var unread = 0

    var body: some View {
        switch session.state {
        case .unknown:
            ProgressView().controlSize(.large)
        case .signedOut:
            SignInView(session: session)
        case .signedIn:
            // The player's tabs, as the web's bottom bar (#362): Играй, then Игри (#510).
            // `.tabItem`, not `Tab`: the app supports iOS 17, and `Tab` is 18.
            TabView {
                VenueListView(session: session)
                    .tabItem { Label(String(localized: "tab.play"), systemImage: "figure.tennis") }
                GamesView(session: session)
                    .tabItem { Label(String(localized: "tab.games"), systemImage: "person.3") }
                InboxView(session: session, unread: $unread)
                    .tabItem { Label(String(localized: "tab.messages"), systemImage: "bubble.left.and.bubble.right") }
                    .badge(unread)
                ProfileView(session: session)
                    .tabItem { Label(String(localized: "tab.profile"), systemImage: "person.crop.circle") }
            }
            // The badge without opening the tab: read on launch, then each minute.
            .task {
                while !Task.isCancelled {
                    if let client = await session.client(),
                       let counts = try? await client.getMyUnreadConversations().ok.body.json.data {
                        unread = counts.conversations + counts.requests
                    }
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }
}
