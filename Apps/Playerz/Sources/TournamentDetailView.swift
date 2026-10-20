import PlayerzAPI
import SwiftUI

/// A tournament (playerz-ios#22), the web's `/tournaments/{id}`: what it is,
/// when and where, the places and the fee; the player's entry, entering
/// (with a partner for doubles) and withdrawing; and the draw.
///
///     not entered, open    «Запиши се»: alone, or with a partner chosen first
///     entered              where the entry stands, the partner, a place on
///                          the waiting list, and «Оттегли се»
struct TournamentDetailView: View {
    let id: String
    @Bindable var session: SessionModel

    @State private var view: Components.Schemas.TournamentView?
    @State private var failed = false
    @State private var partner: Components.Schemas.PlayerCard?
    @State private var choosingPartner = false
    @State private var busy = false
    @State private var problem: String?
    @State private var confirmingWithdraw = false
    @Environment(\.openURL) private var openURL
    /// A DEBUG launch can open the draw at once (DebugLaunch).
    @State private var debugDraw = DebugLaunch.tournamentDraw

    var body: some View {
        Group {
            if let view {
                let tournament = view.value1
                List {
                    Section {
                        Text(TournamentText.kind(tournament))
                        LabeledContent(String(localized: "tournaments.when"), value: TournamentText.dates(tournament))
                        if let close = tournament.entriesCloseAt {
                            LabeledContent(String(localized: "tournaments.entriesClose")) {
                                Text(GameText.when(close, timezone: tournament.venue?.timezone ?? "Europe/Sofia"))
                            }
                        }
                        if let venue = tournament.venue {
                            LabeledContent(String(localized: "tournaments.where"), value: "\(venue.name), \(venue.city)")
                        }
                        LabeledContent(String(localized: "tournaments.club"), value: tournament.club.name)
                        LabeledContent(String(localized: "tournaments.fee"), value: TournamentText.fee(tournament))
                        LabeledContent(TournamentText.places(tournament), value: tournament.pending > 0
                            ? String(localized: "tournaments.waitingCount \(tournament.pending)") : "")
                    } footer: {
                        Text(TournamentText.status(tournament))
                    }
                    if let description = tournament.description, !description.isEmpty {
                        Section { Text(description) }
                    }
                    if let problem {
                        Section { Text(problem).foregroundStyle(.red) }
                    }
                    TournamentEntrySection(
                        tournament: tournament,
                        entry: view.value2.myEntry,
                        partner: partner,
                        busy: busy,
                        choosePartner: choosePartner,
                        enter: enter,
                        withdraw: askToWithdraw,
                        pay: pay
                    )
                    if tournament.status == .IN_PROGRESS || tournament.status == .COMPLETE {
                        Section {
                            NavigationLink(String(localized: "tournaments.draw.heading")) {
                                TournamentDrawView(id: id, timezone: tournament.venue?.timezone ?? "Europe/Sofia", venueId: tournament.venue?.id, session: session)
                            }
                        }
                    }
                }
                .refreshable { await load() }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "tournaments.error.TOURNAMENT_NOT_FOUND"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(view?.value1.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .navigationDestination(isPresented: $debugDraw) {
            TournamentDrawView(id: id, timezone: view?.value1.venue?.timezone ?? "Europe/Sofia", venueId: view?.value1.venue?.id, session: session)
        }
        .sheet(isPresented: $choosingPartner) {
            PartnerPickerSheet(session: session) { chosen in
                partner = chosen
                choosingPartner = false
            }
        }
        .confirmationDialog(
            String(localized: "tournaments.withdrawConfirm.title"),
            isPresented: $confirmingWithdraw,
            titleVisibility: .visible
        ) {
            Button(String(localized: "tournaments.withdrawConfirm.yes"), role: .destructive, action: withdraw)
            Button(String(localized: "tournaments.withdrawConfirm.no"), role: .cancel) {}
        } message: {
            Text(String(localized: "tournaments.withdrawConfirm.description"))
        }
    }

    private func retry() {
        failed = false
        Task { await load() }
    }

    private func choosePartner() {
        choosingPartner = true
    }

    private func askToWithdraw() {
        confirmingWithdraw = true
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            view = try await client.getTournament(path: .init(id: id)).ok.body.json.data
            failed = false
        } catch {
            failed = view == nil
        }
    }

    private func enter() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.enterTournament(
                path: .init(id: id),
                body: .json(.init(partnerUserId: partner?.userId))
            )
            if case let .created(created)? = response, let fresh = try? created.body.json.data {
                view = fresh
                partner = nil
            } else {
                let code = response.flatMap { apiErrorCode($0) }
                if code == "PHONE_REQUIRED" { session.notice(refusal: code) }
                problem = TournamentText.error(code)
            }
        }
    }

    /// Stripe's page for the fee, in Safari: a real-world service, paid as on
    /// the web, never as an in-app purchase (guideline 3.1.3). The entry shows
    /// as paid once Stripe tells the server; pull to refresh.
    private func pay() {
        guard let entry = view?.value2.myEntry else { return }
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.openTournamentEntryCheckout(path: .init(id: entry.id))
            if case let .created(created)? = response, let page = try? created.body.json.data,
               let url = URL(string: page.checkoutUrl) {
                openURL(url)
            } else {
                problem = TournamentText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func withdraw() {
        guard let entry = view?.value2.myEntry else { return }
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.withdrawTournamentEntry(path: .init(id: entry.id))
            if case let .ok(ok)? = response, let fresh = try? ok.body.json.data {
                view = fresh
            } else {
                problem = TournamentText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
