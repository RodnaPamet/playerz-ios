import PlayerzAPI
import SwiftUI

/// Where an entry's online fee stands (#23): due by when, with «Плати таксата»
/// for the one who pays it; paid; or refunded.
struct TournamentPaymentLine: View {
    let payment: Components.Schemas.EntryPayment
    /// Only the entrant pays; a named partner waits for them.
    let entrant: Bool
    let timezone: String
    let pay: () -> Void

    var body: some View {
        switch payment.state {
        case .DUE:
            if entrant {
                if let by = payment.dueBy {
                    Text(String(localized: "tournaments.payment.due \(GameText.when(by, timezone: timezone))"))
                        .foregroundStyle(.orange)
                }
                Button(String(localized: "tournaments.payment.pay"), systemImage: "creditcard", action: pay)
            } else {
                Text(String(localized: "tournaments.payment.dueByEntrant")).foregroundStyle(.secondary)
            }
        case .PAID, .REFUND_DUE, .REFUNDED:
            Text(localized(key: "tournaments.payment.\(payment.state.rawValue)")).foregroundStyle(.secondary)
        }
    }
}
