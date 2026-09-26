import Foundation
import Observation
import PlayerzAPI
import UIKit
import UserNotifications

/// Registers this device for push, and tells the server about it.
///
/// ═══ WHEN IT ASKS, AND WHY NOT AT LAUNCH ═══
///
/// iOS gives an app ONE chance at the permission prompt. Deny it and the app
/// cannot ask again — the user has to find it in Settings, which almost nobody
/// does. Asking on first launch, before anything has happened, is therefore the
/// expensive mistake: it spends the single prompt at the moment the user has
/// least reason to say yes.
///
/// So it asks after a booking succeeds, when "we'll tell you before it starts"
/// is an obvious offer rather than an abstract one, and behind our own dialog
/// first — a "not now" there is recoverable, a "Don't Allow" from the system is
/// not.
///
/// ═══ THE ENVIRONMENT IS DERIVED FROM THE BUILD ═══
///
/// A debug build registers with APNs SANDBOX; TestFlight and the App Store use
/// PRODUCTION. Getting it wrong is not a soft failure: the server sends to the
/// wrong host, Apple answers BadDeviceToken, and — before #208 — the row was
/// DELETED as a dead device. `POST /devices` now refuses a missing value rather
/// than defaulting, which is why this is explicit and not optional.
@MainActor
@Observable
final class PushRegistrar {
    static let shared = PushRegistrar()

    private(set) var deviceToken: String?
    private var registered = false

    /// SANDBOX for debug builds, PRODUCTION for everything shipped.
    static var environment: Components.Schemas.DeviceRegistration.environmentPayload {
        #if DEBUG
            .SANDBOX
        #else
            .PRODUCTION
        #endif
    }

    /// Has the user already been asked? Used to avoid offering twice.
    func alreadyDecided() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus != .notDetermined
    }

    /// Ask, then register. Only call this after our own dialog said yes.
    func requestAndRegister(_ session: SessionModel) async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            return
        }

        // The token arrives through the app delegate, not from this call.
        UIApplication.shared.registerForRemoteNotifications()
        self.session = session
    }

    private weak var session: SessionModel?

    /// Called by the app delegate when Apple hands back a token.
    func tokenArrived(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = hex
        guard !registered, let session else { return }
        registered = true
        Task { await register(hex, session: session) }
    }

    private func register(_ token: String, session: SessionModel) async {
        guard let client = await session.client() else { return }
        _ = try? await client.registerDevice(
            .init(
                body: .json(
                    .init(
                        deviceToken: token,
                        bundleId: Bundle.main.bundleIdentifier ?? "bg.playerz.app",
                        environment: Self.environment,
                        deviceName: UIDevice.current.name,
                        osVersion: UIDevice.current.systemVersion
                    )
                )
            )
        )
        // A failure here is silent on purpose. Registration is an enhancement
        // to a booking that has already succeeded; an error about push beside a
        // confirmed court reads as though the booking itself went wrong.
    }
}
