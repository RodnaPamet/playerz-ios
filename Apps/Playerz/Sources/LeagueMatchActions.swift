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
                // Side by side, or one under the other when the words are large.
                ViewThatFits(in: .horizontal) {
                    HStack { buttons(theirs: theirs) }
                    VStack(alignment: .leading) { buttons(theirs: theirs) }
                }
                .disabled(busy)
            }
        } else {
            Button(String(localized: "tournaments.propose.open"), systemImage: "calendar.badge.plus", action: propose)
                .buttonStyle(.brandSecondary(fullWidth: false))
                .disabled(busy)
        }
    }

    @ViewBuilder
    private func buttons(theirs: Bool) -> some View {
        if theirs {
            Button(String(localized: "tournaments.propose.accept"), action: accept)
                .buttonStyle(.brandPrimary(fullWidth: false))
        }
        Button(
            theirs ? String(localized: "tournaments.propose.decline") : String(localized: "tournaments.propose.withdraw"),
            action: letGo
        )
        .buttonStyle(.brandSecondary(fullWidth: false))
    }
}
