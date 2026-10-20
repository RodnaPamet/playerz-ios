import PlayerzAPI
import SwiftUI

/// One match: both sides, the winner in bold, the score, and its court and
/// time, or what stands instead (a bye, a walkover, a deadline, a proposal).
struct DrawMatchRow: View {
    let match: Components.Schemas.DrawMatch
    let timezone: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            side(0, DrawText.side(match.sideA, match.sideA2))
            side(1, DrawText.side(match.sideB, match.sideB2))
            Text(note).font(.footnote).foregroundStyle(match.overdue ? .orange : .secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func side(_ index: Int, _ name: String) -> some View {
        HStack {
            Text(name).bold(match.winnerSide == index)
            Spacer()
            if let score = match.score {
                Text(score.compactMap { $0.indices.contains(index) ? String($0[index]) : nil }.joined(separator: " "))
                    .monospacedDigit()
                    .bold(match.winnerSide == index)
            }
        }
    }

    private var note: String {
        if match.status == .WALKOVER {
            return match.sideA == nil || match.sideB == nil
                ? String(localized: "tournaments.draw.bye")
                : String(localized: "tournaments.draw.walkover")
        }
        if let scheduled = match.scheduled {
            return String(localized: "tournaments.draw.scheduled \(GameText.when(scheduled.startTs, timezone: timezone)) \(scheduled.courtName)")
        }
        if let proposal = match.proposal {
            return String(localized: "tournaments.draw.proposed \(GameText.when(proposal.startTs, timezone: timezone)) \(proposal.courtName)")
        }
        if match.overdue { return String(localized: "tournaments.draw.overdue") }
        if let deadline = match.deadline {
            let zone = TimeZone(identifier: timezone) ?? .current
            let day = deadline.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day().month(.abbreviated))
            return String(localized: "tournaments.draw.deadline \(day)")
        }
        return match.status == .PLAYED ? "" : String(localized: "tournaments.draw.notScheduled")
    }
}
