import PlayerzAPI
import SwiftUI

/// «Записване»: the player's entry and where it stands, or entering. For
/// doubles the partner is chosen first; they are told, and may withdraw.
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

    var body: some View {
        Section {
            if let entry, entry.status != .WITHDRAWN {
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
                    TournamentPaymentLine(payment: payment, entrant: entry.role == .entrant, timezone: tournament.venue?.timezone ?? "Europe/Sofia", pay: pay)
                        .disabled(busy)
                }
                if entry.status == .PENDING || entry.status == .CONFIRMED {
                    Button(String(localized: "tournaments.withdraw"), role: .destructive, action: withdraw)
                        .disabled(busy)
                }
            } else if tournament.entriesOpen {
                if tournament.teamSize == ._2 {
                    LabeledContent(String(localized: "tournaments.partner.label")) {
                        Button(partner?.name ?? String(localized: "tournaments.partner.choose"), action: choosePartner)
                    }
                }
                Button(
                    tournament.teamSize == ._2 ? String(localized: "tournaments.enterPair") : String(localized: "tournaments.enter"),
                    action: enter
                )
                .disabled(busy || (tournament.teamSize == ._2 && partner == nil))
            } else {
                Text(String(localized: "tournaments.closed")).foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "tournaments.entryHeading"))
        } footer: {
            if entry == nil, tournament.entriesOpen {
                Text(tournament.entryFeeCents > 0 && tournament.feePayment == .AT_CLUB
                    ? String(localized: "tournaments.feeNote")
                    : String(localized: "tournaments.enterNote"))
            }
        }
    }
}
