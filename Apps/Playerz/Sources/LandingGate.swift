import PlayerzAPI
import SwiftUI

/// Where a signed-in account lands (projectZ#167, #296): `GET /me` names the
/// account's kind and `landing.reason`, and the app maps it to its own screens.
///
///   player, coach, anything new  the player's tabs (there is no coach UI yet,
///                                on the web either, and a coach books as a player)
///   undecided                    «Играч или треньор?» first: the choice is made once
///   club, club-unavailable,      a note that a club is run from the web: a club
///   undecided with a club role   account is not a player, and its admin is not here
struct LandingGate<Tabs: View>: View {
    @Bindable var session: SessionModel
    @ViewBuilder let tabs: () -> Tabs

    @State private var me: Components.Schemas.Me?
    @State private var failed = false
    /// An undecided account the server would not let choose: it holds a club role.
    @State private var holdsClubRole = false

    var body: some View {
        Group {
            if let me {
                switch destination(me) {
                case .player: tabs()
                case .chooseKind:
                    AccountKindView(session: session) { chosen in
                        self.me = chosen
                    } holdsClubRole: {
                        holdsClubRole = true
                    }
                case .club: ClubAccountView(session: session)
                }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "profile.failed"))
                } actions: {
                    Button(String(localized: "venues.retry")) { Task { await load() } }
                    Button(String(localized: "common.signOut")) { Task { await session.signOut() } }
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .task { await load() }
    }

    private enum Destination { case player, chooseKind, club }

    private func destination(_ me: Components.Schemas.Me) -> Destination {
        if holdsClubRole { return .club }
        switch me.landing.reason {
        case "club", "club-unavailable": return .club
        // Undecided with a live club lands on it (`landing.club` names it, #6).
        // With none, the account chooses; one holding a role at a club that is
        // not live is refused by the server (ACCOUNT_KIND_NOT_ALLOWED) and
        // shown the club note then.
        case "undecided": return me.landing.club == nil ? .chooseKind : .club
        // `player`, `coach`, and a reason added later: the player's tabs, as the spec says.
        default: return .player
        }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            me = try await client.getMe().ok.body.json.data
            failed = false
        } catch {
            failed = true
        }
    }
}

/// «Играч или треньор?» (#263): chosen once, and never changed.
private struct AccountKindView: View {
    @Bindable var session: SessionModel
    let chosen: (Components.Schemas.Me) -> Void
    let holdsClubRole: () -> Void

    @State private var kind: Components.Schemas.ChooseAccountKindRequest.kindPayload = .PLAYER
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "kind.description"))
                }
                Section(String(localized: "kind.legend")) {
                    Picker(String(localized: "kind.legend"), selection: $kind) {
                        VStack(alignment: .leading) {
                            Text(String(localized: "kind.player"))
                            Text(String(localized: "kind.playerHint")).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(Components.Schemas.ChooseAccountKindRequest.kindPayload.PLAYER)
                        VStack(alignment: .leading) {
                            Text(String(localized: "kind.coach"))
                            Text(String(localized: "kind.coachHint")).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(Components.Schemas.ChooseAccountKindRequest.kindPayload.COACH)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
                Section {
                    Button(String(localized: "kind.continue")) { Task { await choose() } }
                        .disabled(busy)
                }
            }
            .navigationTitle(String(localized: "kind.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.signOut")) { Task { await session.signOut() } }
                }
            }
        }
    }

    private func choose() async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        do {
            let response = try await client.chooseAccountKind(body: .json(.init(kind: kind)))
            switch apiErrorCode(response) {
            case nil:
                if let me = try? await client.getMe().ok.body.json.data { chosen(me) }
            case "ACCOUNT_KIND_ALREADY_SET":
                problem = String(localized: "kind.error.ALREADY_SET")
                if let me = try? await client.getMe().ok.body.json.data { chosen(me) }
            case "ACCOUNT_KIND_NOT_ALLOWED":
                // An older account holding a club role: it is the club's.
                holdsClubRole()
            default:
                problem = String(localized: "kind.error.FAILED")
            }
        } catch {
            problem = String(localized: "kind.error.FAILED")
        }
    }
}

/// A club account (#263): it runs its club from playerz.bg in a browser; the
/// app is for players.
private struct ClubAccountView: View {
    @Bindable var session: SessionModel

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "club.title"), systemImage: "building.2")
        } description: {
            Text(String(localized: "club.description"))
        } actions: {
            Link(String(localized: "club.openWeb"), destination: URL(string: "https://playerz.bg")!)
            Button(String(localized: "common.signOut")) { Task { await session.signOut() } }
        }
    }
}
