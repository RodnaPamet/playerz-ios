import PlayerzAPI
import SwiftUI

/// Where an entry's online fee stands (#23): due by when, paid, or refunded.
/// «Плати таксата» is the screen's main button (`TournamentEntrySection`),
/// for the one who pays it.
struct TournamentPaymentLine: View {
    let payment: Components.Schemas.EntryPayment
    /// Only the entrant pays; a named partner waits for them.
    let entrant: Bool
    let timezone: String

    /// Whether this person has the fee to pay now.
    static func payable(_ payment: Components.Schemas.EntryPayment, entrant: Bool) -> Bool {
        payment.state == .DUE && entrant
    }

    var body: some View {
        switch payment.state {
        case .DUE:
            if entrant {
                if let by = payment.dueBy {
                    // The deadline is what to notice: the accent and a clock, not colour alone.
                    Label(String(localized: "tournaments.payment.due \(GameText.when(by, timezone: timezone))"), systemImage: "clock")
                        .foregroundStyle(Theme.Palette.accentText)
                }
            } else {
                Text(String(localized: "tournaments.payment.dueByEntrant")).foregroundStyle(.secondary)
            }
        case .PAID, .REFUND_DUE, .REFUNDED:
            Text(localized(key: "tournaments.payment.\(payment.state.rawValue)")).foregroundStyle(.secondary)
        }
    }
}
