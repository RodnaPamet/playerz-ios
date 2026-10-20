import PlayerzAPI
import SwiftUI

/// Where a signed-in account lands (projectZ#167, #296): `GET /me` names the
/// account's kind and `landing.reason`, and the app maps it to its own screens.
///
///   player, coach, anything new  the player's tabs: a coach books as a player, and
///                                their own area is «Профил на треньор» in Профил,
///                                as on the web (#20, #21)
///   undecided                    «Играч или треньор?» first: the choice is made once
///   club, club-unavailable,      a note that a club is run from the web: a club
///   undecided with a club role   account is not a player, and its admin is not here
///
/// Before all of them, new terms or a new privacy policy to accept (#10): the
/// server never holds the API back for them, so the app asks, as the web's
/// `/start/terms` does. Checked after loading and on every return to the
/// foreground, since a text can be published while the app is open.
struct LandingGate<Tabs: View>: View {
    @Bindable var session: SessionModel
    @ViewBuilder let tabs: () -> Tabs

    @State private var me: Components.Schemas.Me?
    @State private var failed = false
    /// An undecided account the server would not let choose: it holds a club role.
    @State private var holdsClubRole = false
    /// The texts still to accept; nil until known.
    @State private var owed: OwedTexts?
    /// «Не сега» on the phone step, this launch (also remembered per account).
    @State private var skippedPhone = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if me != nil, let owed, !owed.isEmpty {
                LegalStepView(session: session, owed: owed) { self.owed = $0 }
            } else if let me, offersPhone(me) {
                PhoneStepView(session: session) {
                    Task { await load() }
                } later: {
                    session.rememberAskedForPhone(me.id)
                    skippedPhone = true
                }
            } else if let me {
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
        .task(id: scenePhase) {
            if scenePhase == .active, me != nil { await checkTexts() }
        }
    }

    /// A failed check keeps what was known: an error must not unlock the step,
    /// nor put it up when nothing is owed.
    private func checkTexts() async {
        if let fresh = try? await session.owedTexts() { owed = fresh }
    }

    /// The phone step, offered once (#11): the rule is on, nothing is confirmed
    /// yet, and the account books, plays or writes as a player or a coach.
    private func offersPhone(_ me: Components.Schemas.Me) -> Bool {
        guard !skippedPhone, me.phone.required, !me.phone.verified else { return false }
        guard me.accountKind == "PLAYER" || me.accountKind == "COACH" else { return false }
        return !session.wasAskedForPhone(me.id)
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
            let fresh = try await client.getMe().ok.body.json.data
            // The texts first, so the tabs never show for a moment before the step.
            await checkTexts()
            await session.followLanguage(of: fresh)
            me = fresh
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
