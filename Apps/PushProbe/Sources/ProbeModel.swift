import Foundation
import PlayerzAPI
import UIKit
import UserNotifications

@MainActor
@Observable
final class ProbeModel {
    /// Filled in per run. A cloudflared quick tunnel gets a fresh hostname
    /// every time it starts, so hardcoding one here only ever ships a dead URL:
    ///
    ///     cloudflared tunnel --url http://localhost:3000
    var serverURL = ""
    var email = "owner@sofia.bg"
    var password = "Passw0rd!"

    private(set) var deviceToken: String?
    private(set) var log: [String] = []
    private(set) var busy = false

    private var store: TokenStore?

    func note(_ line: String) { log.append(line) }

    // MARK: - Step 1: ask Apple for a token

    func requestToken() async {
        busy = true
        defer { busy = false }
        note("requesting notification permission…")

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            note(granted ? "permission granted" : "permission DENIED — no token will arrive")
            guard granted else { return }
        } catch {
            note("permission error: \(error.localizedDescription)")
            return
        }

        // Must be on the main actor, and the token comes back through the app
        // delegate rather than from this call.
        UIApplication.shared.registerForRemoteNotifications()
        note("registered; waiting for Apple…")
    }

    func tokenArrived(_ hex: String) {
        deviceToken = hex
        note("token: \(hex.prefix(16))… (\(hex.count) hex chars)")
    }

    func registrationFailed(_ error: Error) {
        note("APNs registration FAILED: \(error.localizedDescription)")
        note("usually a provisioning profile with no aps-environment")
    }

    // MARK: - Step 2: sign in and register it with the server

    func signInAndRegister() async {
        guard let token = deviceToken else {
            note("no device token yet — do step 1 first")
            return
        }
        guard let base = URL(string: serverURL) else {
            note("server URL is not a URL")
            return
        }

        busy = true
        defer { busy = false }

        do {
            // Unauthenticated client for sign-in; the middleware exempts
            // authSignIn anyway, but there is no session to carry yet.
            let anon = Playerz.client(baseURL: base.appendingPathComponent("api/v1"))
            note("signing in as \(email)…")

            let signIn = try await anon.authSignIn(
                .init(body: .json(.init(email: email, password: password)))
            )
            guard case let .ok(ok) = signIn, case let .json(body) = ok.body else {
                note("sign-in rejected: \(signIn)")
                return
            }
            let data = body.data
            guard let refresh = data.refreshToken else {
                note("sign-in returned no refresh token — cannot hold a session")
                return
            }
            note("signed in; access token expires \(data.expiresAt)")

            // Store it the way the real app will: Keychain, via TokenStore.
            let store = TokenStore(persistence: KeychainTokenPersistence())
            try await store.set(
                Tokens(
                    accessToken: data.accessToken,
                    accessExpiresAt: data.expiresAt,
                    refreshToken: refresh,
                    refreshExpiresAt: data.refreshExpiresAt
                )
            )
            self.store = store

            // Authenticated client, through BearerMiddleware.
            let client = Playerz.client(
                baseURL: base.appendingPathComponent("api/v1"),
                middlewares: [
                    BearerMiddleware(tokens: store) { presented in
                        let refreshed = try await anon.authRefresh(
                            .init(body: .json(.init(refreshToken: presented)))
                        )
                        guard case let .ok(ok) = refreshed, case let .json(b) = ok.body else {
                            throw ProbeError.refreshFailed
                        }
                        return Tokens(
                            accessToken: b.data.accessToken,
                            accessExpiresAt: b.data.expiresAt,
                            // Null means KEEP the existing one — the server
                            // returns null inside its rotation grace window.
                            refreshToken: b.data.refreshToken ?? presented,
                            refreshExpiresAt: b.data.refreshExpiresAt
                        )
                    }
                ]
            )

            note("registering device…")
            let result = try await client.registerDevice(
                .init(
                    body: .json(
                        .init(
                            deviceToken: token,
                            bundleId: Bundle.main.bundleIdentifier ?? "bg.playerz.app",
                            // A debug build is a SANDBOX token. The server now
                            // REFUSES a missing value rather than defaulting to
                            // PRODUCTION — which is why this is not optional in
                            // the generated type.
                            environment: .SANDBOX,
                            deviceName: UIDevice.current.name,
                            osVersion: UIDevice.current.systemVersion
                        )
                    )
                )
            )
            note("registerDevice -> \(result)")
        } catch {
            note("failed: \(error)")
        }
    }

}

enum ProbeError: Error { case refreshFailed }
