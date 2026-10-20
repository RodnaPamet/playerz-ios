import PlayerzAPI
import SwiftUI

/// Профил: the account, «Показвай ме в търсенето» (#484), the emails about
/// messages and games (#484, #510), downloading the data and deleting the
/// account (#9), and signing out.
struct ProfileView: View {
    @Bindable var session: SessionModel

    @State private var me: Components.Schemas.Me?
    @State private var settings: Components.Schemas.NotificationSettings?
    @State private var failed = false
    @State private var problem: String?
    // The switches, as the server last said; a change is written back.
    @State private var searchable = true
    @State private var email: [NotificationKind: Bool] = [:]
    @State private var push: [NotificationKind: Bool] = [:]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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

                    if let settings {
                        emailSection
                        // On the phone (#529): only once this account has a device registered.
                        if settings.pushDevices > 0 {
                            pushSection
                        }
                    }

                    if let problem {
                        Section { Text(problem).foregroundStyle(.red) }
                    }

                    if me != nil {
                        AccountDeletionSection(session: session)
                    }

                    Section {
                        Button(String(localized: "common.signOut"), role: .destructive) {
                            Task { await session.signOut() }
                        }
                    }
                }
                .navigationTitle(String(localized: "profile.title"))
                .task {
                    await load()
                    if DebugLaunch.profile != nil {
                    // After the section that `load` revealed has been laid out.
                    try? await Task.sleep(for: .milliseconds(400))
                    proxy.scrollTo(AccountDeletionSection.anchor, anchor: .bottom)
                }
                }
                .refreshable { await load() }
                // Only a change from what the server said is written.
                .onChange(of: searchable) { _, on in
                    if let me, me.searchable != on { Task { await setSearchable(on) } }
                }
                .onChange(of: email) { _, now in
                    guard let settings else { return }
                    for kind in kinds where now[kind] != kind.read(settings.email) {
                        Task { await save(email: kind, now[kind] ?? true) }
                    }
                }
                .onChange(of: push) { _, now in
                    guard let settings else { return }
                    for kind in kinds where now[kind] != kind.read(settings.push) {
                        Task { await save(push: kind, now[kind] ?? true) }
                    }
                }
            }
        }
    }

    private var emailSection: some View {
        Section {
            ForEach(kinds, id: \.self) { kind in
                Toggle(kind.label, isOn: $email[on: kind])
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
                Toggle(kind.label, isOn: $push[on: kind])
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
        email = Dictionary(uniqueKeysWithValues: NotificationKind.allCases.map { ($0, $0.read(fresh.email)) })
        push = Dictionary(uniqueKeysWithValues: NotificationKind.allCases.map { ($0, $0.read(fresh.push)) })
    }

    /// The kinds this account is shown: «Уроци, които водя» is a coach's only.
    private var kinds: [NotificationKind] {
        NotificationKind.allCases.filter { $0 != .lessonsTaught || me?.accountKind == "COACH" }
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

    private func save(email kind: NotificationKind, _ on: Bool) async {
        await save(.init(email: kind.emailChange(on)))
    }

    private func save(push kind: NotificationKind, _ on: Bool) async {
        await save(.init(push: kind.pushChange(on)))
    }

    private func save(_ change: Components.Schemas.UpdateNotificationSettingsRequest) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            show(settings: try await client
                .updateMyNotificationSettings(body: .json(change))
                .ok.body.json.data)
        } catch {
            problem = String(localized: "profile.saveFailed")
            if let settings { show(settings: settings) }
        }
    }
}
