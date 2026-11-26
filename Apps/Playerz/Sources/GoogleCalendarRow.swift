import AuthenticationServices
import PlayerzAPI
import SwiftUI

/// «Синхронизирай с Google Календар» in Профил: one switch, as Agrent's
/// «Копие в Google Drive» (owner 2026-11-14). On: first what we will read and
/// who sees what, in the server's own words (projectZ #713, Google's user-data
/// policy wants it in the flow, right before consent); «Свържи» is the
/// agreement. Then Google's consent in a sheet, and the server keeps the player's bookings, games, lessons and
/// tournament matches in a «playerz» calendar in their Google account. Off:
/// the connection is removed; the calendar and its events stay in Google.
/// Hidden while the server has the feature off.
struct GoogleCalendarRow: View {
    @Bindable var session: SessionModel

    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var state: Components.Schemas.MyCalendar.googlePayload?
    @State private var disclosure: Components.Schemas.GoogleCalendarDisclosure?
    @State private var askingConsent = false
    @State private var available = false
    @State private var busy = false
    @State private var problem: String?

    /// Where the server sends the sheet back: caught by the sheet itself,
    /// nothing is registered in Info.plist.
    static let callbackScheme = "bg.playerz.app"

    var body: some View {
        Group {
            if available {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ProfileHubRow(
                        String(localized: "calendar.google.title"),
                        subtitle: subtitle,
                        systemImage: "calendar.badge.clock"
                    ) {
                        Toggle(String(localized: "calendar.google.title"), isOn: switchBinding)
                            .labelsHidden()
                            .tint(Theme.Palette.controlOn)
                            .disabled(busy)
                    }
                    if state?.connected == true {
                        Button {
                            Task { await syncNow() }
                        } label: {
                            Label(String(localized: "calendar.google.syncNow"), systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.Palette.accentText)
                        .disabled(busy)
                        .padding(.leading, 56)
                    }
                    if let problem {
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(Theme.Palette.danger)
                            .padding(.leading, 56)
                    }
                }
                .hubDivider()
            }
        }
        .task { await load() }
        .brandSheet(isPresented: $askingConsent, detents: [.large]) {
            if let disclosure {
                CalendarConsentSheet(
                    disclosure: disclosure,
                    privacy: URL(string: session.serverURL + "/privacy"),
                    connect: {
                        askingConsent = false
                        Task { await connect(agreeingTo: disclosure.version) }
                    },
                    cancel: { askingConsent = false }
                )
            }
        }
    }

    /// «Свързан с ivan@gmail.com · последно 14:05», «Свържете отново», or what it does.
    private var subtitle: String {
        guard let state else { return String(localized: "calendar.google.hint") }
        if state.error == .GOOGLE_REVOKED { return String(localized: "calendar.google.reconnect") }
        guard state.connected else { return String(localized: "calendar.google.hint") }
        var parts: [String] = []
        if let email = state.email { parts.append(String(localized: "calendar.google.connectedAs \(email)")) }
        if let at = state.lastSyncAt {
            parts.append(String(localized: "calendar.google.lastSync \(at.formatted(date: .abbreviated, time: .shortened))"))
        }
        return parts.isEmpty ? String(localized: "calendar.google.hint") : parts.joined(separator: " · ")
    }

    private var switchBinding: Binding<Bool> {
        Binding(get: { state?.connected ?? false }, set: { on in
            if on {
                // The words first; Google only after «Свържи».
                if disclosure != nil { askingConsent = true } else { Task { await load(); askingConsent = disclosure != nil } }
            } else {
                Task { await disconnect() }
            }
        })
    }

    private func load() async {
        guard let client = await session.client() else { return }
        let locale: Operations.getMyCalendar.Input.Query.localePayload = AppLanguageChoice.current == .en ? .en : .bg
        switch try? await client.getMyCalendar(query: .init(locale: locale)) {
        case let .ok(ok)?:
            let data = try? ok.body.json.data
            state = data?.google
            disclosure = data?.disclosure
            available = true
        default:
            // 404 GOOGLE_CALENDAR_SYNC_DISABLED, or nothing read: no row.
            available = false
        }
    }

    private func connect(agreeingTo version: String) async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        do {
            let response = try await client.connectGoogleCalendar(
                body: .json(.init(client: .ios, disclosureVersion: version))
            )
            if case .conflict = response {
                // The words changed while the sheet was open: show the new ones.
                await load()
                problem = String(localized: "calendar.google.disclosureChanged")
                askingConsent = disclosure != nil
                return
            }
            let url = try response.ok.body.json.data.authorizeUrl
            guard let authorize = URL(string: url) else { throw URLError(.badURL) }
            // Ephemeral, as sign-in's sheet: the person picks the Google account.
            let callback = try await webAuthenticationSession.authenticate(
                using: authorize, callbackURLScheme: Self.callbackScheme, preferredBrowserSession: .ephemeral
            )
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let code = items.first(where: { $0.name == "error" })?.value {
                problem = Self.message(for: code)
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closed by the person: the switch simply stays off.
        } catch {
            problem = String(localized: "calendar.google.failed")
        }
        await load()
    }

    private func disconnect() async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        if (try? await client.disconnectGoogleCalendar()) == nil {
            problem = String(localized: "calendar.google.failed")
        }
        await load()
    }

    private func syncNow() async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        switch try? await client.syncGoogleCalendar() {
        case .ok?: break
        default: problem = String(localized: "calendar.google.syncFailed")
        }
        await load()
    }

    /// The server's closed set of callback codes, in the person's words.
    nonisolated static func message(for code: String) -> String {
        switch code {
        case "access_denied": String(localized: "calendar.google.denied")
        case "insufficient_scope": String(localized: "calendar.google.scope")
        case "state_expired", "state_invalid": String(localized: "calendar.google.expired")
        default: String(localized: "calendar.google.failed")
        }
    }
}

/// What connecting means, before Google is asked (projectZ #713): the
/// server's title and points, word for word, a link to the privacy policy,
/// and «Свържи» / «Отказ». Nothing is sent to Google until «Свържи».
private struct CalendarConsentSheet: View {
    let disclosure: Components.Schemas.GoogleCalendarDisclosure
    let privacy: URL?
    let connect: () -> Void
    let cancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(disclosure.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(Array(disclosure.points.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            Text("•").accessibilityHidden(true)
                            Text(point).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let privacy {
                    Link(String(localized: "calendar.google.privacyLink"), destination: privacy)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accentText)
                }
                VStack(spacing: Theme.Spacing.s) {
                    Button(disclosure.connect, action: connect)
                        .buttonStyle(.brandPrimary)
                    Button(disclosure.cancel, action: cancel)
                        .buttonStyle(.brandSecondary)
                }
            }
            .padding(Theme.Spacing.l)
        }
    }
}
