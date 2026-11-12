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
    /// The name is on the card at the top; the header carries it only once the card is scrolled away.
    @State private var heroShown = true
    /// A DEBUG launch can open the draw at once (DebugLaunch).
    @State private var debugDraw = DebugLaunch.tournamentDraw

    var body: some View {
        Group {
            if let view {
                let tournament = view.value1
                List {
                    Section {
                        TournamentHero(tournament: tournament)
                            .onAppear { heroShown = true }
                            .onDisappear { heroShown = false }
                    }
                    // The card is its own surface: no row box around it.
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    Group {
                        Section {
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
                        }
                        if let description = tournament.description, !description.isEmpty {
                            Section { Text(description) }
                        }
                        if let problem {
                            Section {
                                // The words say it went wrong; the colour and the sign only back them up.
                                Label(problem, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(Theme.Palette.danger)
                            }
                        }
                    }
                    .brandListRow()
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
                            NavigationLink {
                                TournamentDrawView(id: id, timezone: tournament.venue?.timezone ?? "Europe/Sofia", venueId: tournament.venue?.id, session: session)
                            } label: {
                                Label(String(localized: "tournaments.draw.heading"), systemImage: "list.bullet.indent")
                            }
                        }
                        .brandListRow()
                    }
                }
                .refreshable { await load() }
            } else if failed {
                BrandEmptyState(systemImage: "trophy", title: String(localized: "tournaments.error.TOURNAMENT_NOT_FOUND")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView()
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(view?.value1.name ?? "")
        // The name is on the card at the top; the band carries it once the card is scrolled away (#55).
        .brandHeader(.back(heroShown && view != nil ? "" : view?.value1.name ?? ""))
        .task { await load() }
        .navigationDestination(isPresented: $debugDraw) {
            TournamentDrawView(id: id, timezone: view?.value1.venue?.timezone ?? "Europe/Sofia", venueId: view?.value1.venue?.id, session: session)
        }
        // The keyboard and the results need the room: the whole height, not hugged.
        .brandSheet(isPresented: $choosingPartner, detents: [.large]) {
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

/// The top of a tournament's screen: where it stands, its name, what kind it
/// is and when.
private struct TournamentHero: View {
    let tournament: Components.Schemas.Tournament

    var body: some View {
        BrandContentCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                BrandBadge(TournamentText.status(tournament), style: TournamentRow.badgeStyle(tournament))
                Text(tournament.name)
                    .font(Theme.Typography.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(TournamentText.kind(tournament))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accentText)
                Label(TournamentText.dates(tournament), systemImage: "calendar")
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }
}
