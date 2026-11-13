import PlayerzAPI
import SwiftUI

/// Профил, as a hub: who is signed in, tiles to the player's own things, and
/// rows to everything the account can set: «Показвай ме в търсенето» (#484),
/// the emails and the pushes (#484, #510, #529), «Класиране» (#18), a
/// coach's area (#20), the data and deleting the account (#9), signing out.
struct ProfileView: View {
    @Bindable var session: SessionModel

    @State private var debugCoach = DebugLaunch.profile == .coach
    /// A DEBUG launch can land on the delete button, now one screen in.
    @State private var debugAccount = DebugLaunch.profile == .delete || DebugLaunch.profile == .confirm
    /// …or «Класиране».
    @State private var debugRatings = DebugLaunch.profile == .ratings
    @State private var me: Components.Schemas.Me?
    @State private var ratings: Components.Schemas.MyRatings?
    /// The tiles' numbers (projectZ#677).
    @State private var summary: Components.Schemas.MySummary?
    @State private var failed = false
    @State private var problem: String?
    // The switch, as the server last said; a change is written back.
    @State private var searchable = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if let me {
                        ProfileIdentityCard(
                            name: me.name ?? String(localized: "messages.unnamed"),
                            email: me.email,
                            avatarURL: session.mediaURL(me.avatarUrl),
                            levels: levels
                        )
                    } else if failed {
                        failure
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .accessibilityLabel(String(localized: "common.loading"))
                    }

                    ProfileHubTiles(tiles: tiles)

                    if let me {
                        settingsGroup(me)
                    }
                    accountGroup
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .brandPage()
            // Hidden with the system bar, but still what a pushed screen's back button says.
            .navigationTitle(String(localized: "profile.title"))
            .brandHeader(.title(String(localized: "profile.title"))) {
                BrandHeaderActions(session: session)
            }
            // A DEBUG launch can open «Профил на треньор» or the delete button (DebugLaunch).
            .navigationDestination(isPresented: $debugCoach) {
                CoachProfileView(session: session)
            }
            .navigationDestination(isPresented: $debugAccount) {
                AccountDataView(session: session)
            }
            .navigationDestination(isPresented: $debugRatings) {
                MyRatingsView(session: session)
            }
            .task { await load() }
            .refreshable { await load() }
            // `task` runs once in the shell: the level, the coach link and
            // the switch are read again on each return. `load` never clears
            // what is shown, so the scroll position stays.
            .onShellTabReturn { await load() }
            // Only a change from what the server said is written.
            .onChange(of: searchable) { _, on in
                if let me, me.searchable != on { Task { await setSearchable(on) } }
            }
        }
    }

    // MARK: - Parts

    /// Where the player's own things are. A tile is only there while its
    /// module is on, and carries a number only where the server counts one.
    private var tiles: [ProfileHubTile] {
        var tiles: [ProfileHubTile] = []
        if session.modules.openPlay {
            // Requests still waiting for an answer: what the player is watching for.
            let waiting = summary?.pendingGameRequests ?? 0
            tiles.append(.init(
                id: "games",
                title: String(localized: "tab.games"),
                systemImage: "figure.tennis",
                count: waiting,
                spokenCount: String(localized: "profile.tile.waiting \(waiting)"),
                calm: true
            ) {
                session.requestedTab = .games
            })
        }
        let upcoming = summary?.upcomingBookings ?? 0
        tiles.append(.init(
            id: "bookings",
            title: String(localized: "tab.bookings"),
            systemImage: "calendar",
            count: upcoming,
            spokenCount: String(localized: "profile.tile.upcoming \(upcoming)"),
            calm: true
        ) {
            session.requestedTab = .bookings
        })
        if session.modules.messaging {
            tiles.append(.init(
                id: "messages",
                title: String(localized: "messages.title"),
                systemImage: "bubble.left.and.bubble.right",
                count: session.messagesUnread,
                spokenCount: String(localized: "messages.unread \(session.messagesUnread)")
            ) {
                session.messagesOpen = true
            })
        }
        // With a module off there is room for the bell's list as a tile too.
        if tiles.count < 3 {
            tiles.append(.init(
                id: "notifications",
                title: String(localized: "notifications.title"),
                systemImage: "bell",
                count: session.notificationsUnread,
                spokenCount: String(localized: "notifications.unread \(session.notificationsUnread)")
            ) {
                session.notificationsOpen = true
            })
        }
        return tiles
    }

    /// «Падел · Ниво 4,0» for each rated sport, while the ranking module is on.
    private var levels: [String] {
        guard session.modules.ranking, let ratings else { return [] }
        return ratings.items.map {
            GameText.sport($0.sport) + " · " + RatingText.level($0.level, provisional: $0.provisional)
        }
    }

    private func settingsGroup(_ me: Components.Schemas.Me) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ProfileHubGroup(title: String(localized: "profile.hub.settings")) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Toggle(isOn: $searchable) {
                        Text(String(localized: "profile.searchable")).font(Theme.Typography.rowTitle)
                    }
                    .tint(Theme.Palette.controlOn)
                    // Under the switch, not beside it: the explanation keeps
                    // the card's width at every text size.
                    Text(String(localized: "profile.searchableHint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .frame(minHeight: Theme.minTarget)
                // The hint is the switch's, for VoiceOver too.
                .accessibilityElement(children: .combine)

                // Bulgarian unless chosen here (owner 2026-11-13): each
                // language named in itself, so it can be found from either.
                ProfileHubRow(String(localized: "profile.language"), systemImage: "globe") {
                    Picker(String(localized: "profile.language"), selection: language) {
                        Text(verbatim: "Български").tag(AppLanguage.Code.bg)
                        Text(verbatim: "English").tag(AppLanguage.Code.en)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    // The language's whole name, not broken over two lines.
                    .fixedSize()
                    .tint(Theme.Palette.accentText)
                }
                .hubDivider()

                NavigationLink {
                    NotificationSettingsView(session: session, isCoach: me.accountKind == "COACH")
                } label: {
                    ProfileHubRow(
                        String(localized: "profile.hub.alerts"),
                        subtitle: String(localized: "profile.hub.alertsHint"),
                        systemImage: "envelope"
                    )
                }
                .buttonStyle(.plain)
                .hubDivider()

                // «Класиране» (#18), while the ranking module is on.
                if session.modules.ranking {
                    NavigationLink {
                        MyRatingsView(session: session)
                    } label: {
                        ProfileHubRow(String(localized: "profile.ratings.title"), systemImage: "chart.bar")
                    }
                    .buttonStyle(.plain)
                    .hubDivider()
                }

                // A coach's own area (#20), as the web's «Профил на треньор».
                if me.accountKind == "COACH", session.modules.coaches {
                    NavigationLink {
                        CoachProfileView(session: session)
                    } label: {
                        ProfileHubRow(String(localized: "coachProfile.title"), systemImage: "graduationcap")
                    }
                    .buttonStyle(.plain)
                    .hubDivider()
                }
            }
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.danger)
                    .padding(.horizontal, Theme.Spacing.l)
            }
        }
    }

    private var language: Binding<AppLanguage.Code> {
        Binding(get: { session.language }, set: { code in Task { await session.chooseLanguage(code) } })
    }

    /// Signing out stays reachable when the profile did not load.
    private var accountGroup: some View {
        ProfileHubGroup(title: String(localized: "profile.hub.account")) {
            if me != nil {
                NavigationLink {
                    AccountDataView(session: session)
                } label: {
                    ProfileHubRow(String(localized: "profile.hub.data"), systemImage: "person.text.rectangle")
                }
                .buttonStyle(.plain)
            }
            Button {
                Task { await session.signOut() }
            } label: {
                ProfileHubRow(
                    String(localized: "common.signOut"),
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: Theme.Palette.danger
                ) { EmptyView() }
            }
            .buttonStyle(.plain)
            .hubDivider()
        }
    }

    private var failure: some View {
        BrandContentCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Label(String(localized: "profile.failed"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.Palette.danger)
                Button(String(localized: "notifications.retry")) { Task { await load() } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Data

    private func load() async {
        guard let client = await session.client() else {
            failed = me == nil
            return
        }
        do {
            show(try await client.getMe().ok.body.json.data)
            failed = false
        } catch {
            failed = me == nil
        }
        if session.modules.ranking,
           let fresh = try? await client.getMyRatings().ok.body.json.data {
            ratings = fresh
        }
        if let fresh = try? await client.getMySummary().ok.body.json.data {
            summary = fresh
        }
    }

    private func show(_ fresh: Components.Schemas.Me) {
        me = fresh
        searchable = fresh.searchable
    }

    /// Whether other players find this person by name to write to them (#375).
    private func setSearchable(_ on: Bool) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            show(try await client.updateMe(body: .json(.init(searchable: on))).ok.body.json.data)
        } catch {
            problem = String(localized: "profile.saveFailed")
            if let me { searchable = me.searchable }
        }
    }
}
