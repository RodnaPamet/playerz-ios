import PlayerzAPI
import SwiftUI

/// Профил: the account, «Показвай ме в търсенето» (#484), the emails about
/// messages and games (#484, #510), and signing out.
struct ProfileView: View {
    @Bindable var session: SessionModel

    @State private var me: Components.Schemas.Me?
    @State private var settings: Components.Schemas.NotificationSettings?
    @State private var failed = false
    @State private var problem: String?
    // The switches, as the server last said; a change is written back.
    @State private var searchable = true
    @State private var emailMessages = true
    @State private var emailOpenPlay = true

    var body: some View {
        NavigationStack {
            Form {
                if let me {
                    Section {
                        Text(me.name ?? String(localized: "messages.unnamed")).font(.headline)
                        Text(me.email).foregroundStyle(.secondary)
                    }
                    Section {
                        Toggle(String(localized: "profile.searchable"), isOn: $searchable)
                    } footer: {
                        Text(String(localized: "profile.searchableHint"))
                    }
                } else if failed {
                    Text(String(localized: "profile.failed")).foregroundStyle(.red)
                } else {
                    ProgressView()
                }

                if settings != nil {
                    Section(String(localized: "profile.emails")) {
                        Toggle(String(localized: "profile.email.messages"), isOn: $emailMessages)
                        Toggle(String(localized: "profile.email.openPlay"), isOn: $emailOpenPlay)
                    }
                }

                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }

                Section {
                    Button(String(localized: "common.signOut"), role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            }
            .navigationTitle(String(localized: "profile.title"))
            .task { await load() }
            .refreshable { await load() }
            // Only a change from what the server said is written.
            .onChange(of: searchable) { _, on in
                if let me, me.searchable != on { Task { await setSearchable(on) } }
            }
            .onChange(of: emailMessages) { _, on in
                if let settings, settings.email.messages != on { Task { await setEmail(.init(messages: on)) } }
            }
            .onChange(of: emailOpenPlay) { _, on in
                if let settings, settings.email.openPlay != on { Task { await setEmail(.init(openPlay: on)) } }
            }
        }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            show(me: try await client.getMe().ok.body.json.data)
            failed = false
        } catch {
            failed = me == nil
        }
        if let fresh = try? await client.getMyNotificationSettings().ok.body.json.data {
            show(settings: fresh)
        }
    }

    private func show(me fresh: Components.Schemas.Me) {
        me = fresh
        searchable = fresh.searchable
    }

    private func show(settings fresh: Components.Schemas.NotificationSettings) {
        settings = fresh
        emailMessages = fresh.email.messages
        emailOpenPlay = fresh.email.openPlay
    }

    /// Whether other players find this person by name to write to them (#375).
    private func setSearchable(_ on: Bool) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            show(me: try await client.updateMe(body: .json(.init(searchable: on))).ok.body.json.data)
        } catch {
            problem = String(localized: "profile.saveFailed")
            if let me { searchable = me.searchable }
        }
    }

    private func setEmail(_ change: Components.Schemas.UpdateNotificationSettingsRequest.emailPayload) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            show(settings: try await client
                .updateMyNotificationSettings(body: .json(.init(email: change)))
                .ok.body.json.data)
        } catch {
            problem = String(localized: "profile.saveFailed")
            if let settings { show(settings: settings) }
        }
    }
}
