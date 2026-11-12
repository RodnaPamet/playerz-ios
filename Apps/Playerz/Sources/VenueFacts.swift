import Foundation

/// What a venue's card and a venue's own screen say in chips, and how
/// VoiceOver hears it.
enum VenueFacts {
    /// «от 24,00 €». The summary carries no currency; every club is in euro
    /// (as the list has shown it since the first version).
    /// In the club's currency since the server names it (projectZ#667); EUR
    /// when it does not, as every club so far charges.
    static func price(fromCents cents: Int, currency: String? = nil) -> String {
        let money = (Decimal(cents) / 100).formatted(
            .currency(code: currency ?? "EUR").locale(Locale(identifier: "bg_BG"))
        )
        return String(format: String(localized: "venues.fromPrice"), money)
    }

    /// Nil with no reviews: the server's 0 means "none yet", not a bad score.
    static func rating(_ average: Double, count: Int) -> (shown: String, spoken: String)? {
        guard count > 0 else { return nil }
        let score = average.formatted(.number.precision(.fractionLength(1)))
        return ("\(score) (\(count))", String(localized: "venues.a11y.rating \(score) \(count)"))
    }

    static func sports(_ codes: [String]) -> [String] {
        codes.map(GameText.sport)
    }
}
