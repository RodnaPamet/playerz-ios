import PlayerzAPI
import SwiftUI

/// «Записване»: the player's entry and where it stands, or entering. For
/// doubles the partner is chosen first; they are told, and may withdraw.
///
/// Rows on the card token, and the one main action (enter, or pay the fee)
/// as the accent pill on the page under them.
struct TournamentEntrySection: View {
    let tournament: Components.Schemas.Tournament
    let entry: Components.Schemas.MyTournamentEntry?
    let partner: Components.Schemas.PlayerCard?
    let busy: Bool
    let choosePartner: () -> Void
    let enter: () -> Void
    let withdraw: () -> Void
    /// The online fee's page (#23).
    let pay: () -> Void

    private var doubles: Bool { tournament.teamSize == ._2 }

    var body: some View {
        if let entry, entry.status != .WITHDRAWN {
            entered(entry)
        } else if tournament.entriesOpen {
            entering
        } else {
            Section {
                Text(String(localized: "tournaments.closed")).foregroundStyle(.secondary)
            } header: {
                heading
            }
            .brandListRow()
        }
    }

    private var heading: some View {
        Text(String(localized: "tournaments.entryHeading"))
    }

    @ViewBuilder
    private func entered(_ entry: Components.Schemas.MyTournamentEntry) -> some View {
        Section {
            LabeledContent(String(localized: "tournaments.entryHeading"), value: TournamentText.entry(entry.status))
            if let other = entry.partner {
                Text(entry.role == .entrant
                    ? String(localized: "tournaments.withPartner \(TournamentText.person(other))")
                    : String(localized: "tournaments.namedBy \(TournamentText.person(other))"))
            }
            if let place = entry.waitingPosition {
                Text(String(localized: "tournaments.waitingPosition \(place)")).foregroundStyle(.secondary)
            }
            if let payment = entry.payment {
                TournamentPaymentLine(payment: payment, entrant: entry.role == .entrant, timezone: tournament.venue?.timezone ?? "Europe/Sofia")
            }
            if entry.status == .PENDING || entry.status == .CONFIRMED {
                Button(role: .destructive, action: withdraw) {
                    Text(String(localized: "tournaments.withdraw"))
                        .foregroundStyle(Theme.Palette.danger)
                }
                .disabled(busy)
            }
        } header: {
            heading
        }
        .brandListRow()
        if let payment = entry.payment, TournamentPaymentLine.payable(payment, entrant: entry.role == .entrant) {
            Section {
                Button(action: pay) {
                    Label(String(localized: "tournaments.payment.pay"), systemImage: "creditcard")
                }
                .buttonStyle(.brandPrimary)
                .disabled(busy)
            }
            .bareListRow()
        }
    }

    @ViewBuilder
    private var entering: some View {
        if doubles {
            Section {
                LabeledContent(String(localized: "tournaments.partner.label")) {
                    Button(partner?.name ?? String(localized: "tournaments.partner.choose"), action: choosePartner)
                }
            } header: {
                heading
            }
            .brandListRow()
        }
        Section {
            Button(doubles ? String(localized: "tournaments.enterPair") : String(localized: "tournaments.enter"), action: enter)
                .buttonStyle(.brandPrimary)
                .disabled(busy || (doubles && partner == nil))
        } header: {
            // Singles have no partner row: the heading goes over the button.
            if !doubles { heading }
        } footer: {
            Text(tournament.entryFeeCents > 0 && tournament.feePayment == .AT_CLUB
                ? String(localized: "tournaments.feeNote")
                : String(localized: "tournaments.enterNote"))
        }
        .bareListRow()
    }
}
