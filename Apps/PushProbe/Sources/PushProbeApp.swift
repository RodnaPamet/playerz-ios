import OSLog
import PlayerzAPI
import SwiftUI
import UserNotifications

/// A single-purpose app: get a real APNs device token onto a real server.
///
/// #166 says the APNs path "has never run against Apple" and is wired but
/// unexercised. `scripts/apns-preflight.ts` already proved the CREDENTIALS
/// without hardware, by sending to a dead token and reading how far Apple got.
/// The one thing that cannot be faked is a token issued by Apple to a real
/// device, and that needs an installed app with the push entitlement.
///
/// This is the smallest thing that produces one. It deliberately goes through
/// `PlayerzAPI` rather than URLSession, so the generated client, the bearer
/// middleware and the Keychain store are all exercised on device rather than
/// only in unit tests.
@main
struct PushProbeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup { ProbeView(model: delegate.model) }
    }
}

/// Where the device token arrives.
///
/// APNs registration is a UIApplicationDelegate callback and nothing else —
/// there is no async alternative — so the delegate exists purely to hand the
/// token to the model.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = ProbeModel()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // ═══ WITHOUT THIS, A DELIVERED PUSH LOOKS LIKE A LOST ONE ═══
        //
        // iOS does not display a banner for the app that is CURRENTLY IN THE
        // FOREGROUND unless the app says to. Apple returns 200, the phone
        // receives it, and nothing appears on screen — which is exactly what a
        // failed send looks like from the outside.
        //
        // That matters most here of all: the person testing push is, by
        // definition, staring at the app that just asked for the token.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show it even while the app is open.
    ///
    /// `nonisolated` for the same reason as the handler below: this type is
    /// main-actor isolated by its UIApplicationDelegate conformance, and
    /// `UNNotification` is not Sendable, so it cannot be handed across. Only
    /// the extracted string crosses.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let content = notification.request.content
        let line = "RECEIVED: \(content.title) — \(content.body)"
        await MainActor.run { model.note(line) }
        return [.banner, .sound, .list]
    }

    /// And record a tap on one, so a background delivery leaves evidence too.
    ///
    /// `nonisolated` because `UIApplicationDelegate` conformance puts this type
    /// on the main actor, and the callback's parameters are not Sendable — so
    /// the compiler will not hand them across. The strings are pulled out here,
    /// off the actor, and only those cross.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let line = "OPENED: \(content.title) — \(content.body)"
        await MainActor.run { model.note(line) }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Apple hands back raw bytes; the APNs REST path wants lowercase hex.
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await model.tokenArrived(hex) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // The usual cause is a provisioning profile without aps-environment,
        // which looks like nothing happening at all if it is swallowed.
        Task { await model.registrationFailed(error) }
    }
}
