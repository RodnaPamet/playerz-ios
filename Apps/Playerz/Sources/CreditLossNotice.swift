import PlayerzAPI
import SwiftUI

/// «Ще загубите кредита си» (projectZ#628): the unused credit at each club
/// that deleting the account loses, as the web lists it.
struct CreditLossNotice: View {
    let credit: [DeletionCheck.Credit]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(String(localized: "profile.delete.credit.title"), systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(String(localized: "profile.delete.credit.body"))
            ForEach(credit) { line in
                let amount = (Decimal(line.amountCents) / 100).formatted(.currency(code: line.currency))
                Text(String(localized: "profile.delete.credit.line \(line.club) \(amount)")).bold()
            }
            Text(String(localized: "profile.delete.credit.hint")).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
