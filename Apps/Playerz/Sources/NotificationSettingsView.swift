import PlayerzAPI
import SwiftUI

/// «Имейли и известия» from Профил: which emails and which pushes this
/// person gets (#375, #376, #529, #550). The bell always shows everything.
struct NotificationSettingsView: View {
    @Bindable var session: SessionModel
    /// «Уроци, които водя» is a coach's only.
    let isCoach: Bool

    @State private var settings: Components.Schemas.NotificationSettings?
    @State private var failed = false
    @State private var problem: String?
    // The switches, as the server last said; a change is written back.
    @State private var email: [NotificationKind: Bool] = [:]
    @State private var push: [NotificationKind: Bool] = [:]

    var body: some View {
        Form {
            Group {
                if let settings {
                    emailSection
                    // On the phone (#529): only once this account has a device registered.
                    if settings.pushDevices > 0 {
                        pushSection
                    }
                } else if failed {
                    Section {
                        Text(String(localized: "profile.failed")).foregroundStyle(Theme.Palette.danger)
                        Button(String(localized: "notifications.retry")) { Task { await load() } }
                    }
                } else {
                    ProgressView()
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(Theme.Palette.danger) }
                }
            }
            .brandListRow()
        }
        .brandPage()
        .navigationTitle(String(localized: "profile.hub.alerts"))
        .brandHeader(.back(String(localized: "profile.hub.alerts")))
        .task { await load() }
        .refreshable { await load() }
        // Only a change from what the server said is written.
        .onChange(of: email) { _, now in
            guard let settings else { return }
            for kind in kinds where now[kind] != kind.read(settings.email) {
                Task { await save(.init(email: kind.emailChange(now[kind] ?? true))) }
            }
        }
        .onChange(of: push) { _, now in
            guard let settings else { return }
            for kind in kinds where now[kind] != kind.read(settings.push) {
                Task { await save(.init(push: kind.pushChange(now[kind] ?? true))) }
            }
        }
    }

    private var emailSection: some View {
        Section {
            ForEach(kinds, id: \.self) { kind in
                Toggle(kind.label, isOn: $email[on: kind]).tint(Theme.Palette.controlOn)
            }
        } header: {
            Text(String(localized: "profile.emails"))
        } footer: {
            Text(String(localized: "profile.emailsHint"))
        }
    }

    private var pushSection: some View {
        Section(String(localized: "profile.push")) {
            ForEach(kinds, id: \.self) { kind in
                Toggle(kind.label, isOn: $push[on: kind]).tint(Theme.Palette.controlOn)
            }
        }
    }

    private var kinds: [NotificationKind] {
        NotificationKind.allCases.filter { $0 != .lessonsTaught || isCoach }
    }

    private func load() async {
        guard let client = await session.client(),
              let fresh = try? await client.getMyNotificationSettings().ok.body.json.data else {
            failed = settings == nil
            return
        }
        failed = false
        show(fresh)
    }

    private func show(_ fresh: Components.Schemas.NotificationSettings) {
        settings = fresh
        email = Dictionary(uniqueKeysWithValues: NotificationKind.allCases.map { ($0, $0.read(fresh.email)) })
        push = Dictionary(uniqueKeysWithValues: NotificationKind.allCases.map { ($0, $0.read(fresh.push)) })
    }

    private func save(_ change: Components.Schemas.UpdateNotificationSettingsRequest) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            show(try await client
                .updateMyNotificationSettings(body: .json(change))
                .ok.body.json.data)
        } catch {
            problem = String(localized: "profile.saveFailed")
            if let settings { show(settings) }
        }
    }
}
