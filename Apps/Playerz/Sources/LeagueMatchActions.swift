import PlayerzAPI
import SwiftUI

/// A league match's time (#23), under its row in the draw: «Предложи час»;
/// or the proposal waiting, with «Приеми» and «Откажи» for the other side and
/// «Оттегли» for the side that proposed it.
struct LeagueMatchActions: View {
    let match: Components.Schemas.DrawMatch
    let timezone: String
    let busy: Bool
    let propose: () -> Void
    let accept: () -> Void
    let letGo: () -> Void

    var body: some View {
        if let proposal = match.proposal {
            let theirs = proposal.side != match.mySide
            let when = GameText.when(proposal.startTs, timezone: timezone)
            let until = GameText.when(proposal.until, timezone: timezone)
            VStack(alignment: .leading, spacing: 8) {
                Text(theirs
                    ? String(localized: "tournaments.propose.theirs \(when) \(proposal.courtName) \(until)")
                    : String(localized: "tournaments.propose.ours \(when) \(proposal.courtName) \(until)"))
                    .font(.footnote)
                HStack {
                    if theirs {
                        Button(String(localized: "tournaments.propose.accept"), action: accept)
                            .buttonStyle(.borderedProminent)
                    }
                    Button(
                        theirs ? String(localized: "tournaments.propose.decline") : String(localized: "tournaments.propose.withdraw"),
                        action: letGo
                    )
                    .buttonStyle(.bordered)
                }
                .disabled(busy)
            }
        } else {
            Button(String(localized: "tournaments.propose.open"), action: propose)
                .disabled(busy)
        }
    }
}
