import Foundation

/// A rating on the 1–7 scale, as the web's `useLevelLabel` says it:
/// «Ниво 4,3», and «Ниво 4,3 (неокончателно)» while it is provisional.
enum RatingText {
    static func level(_ level: Double, provisional: Bool) -> String {
        let shown = level.formatted(.number.precision(.fractionLength(1)))
        return provisional
            ? String(localized: "profile.sports.ratedProvisional \(shown)")
            : String(localized: "profile.sports.rated \(shown)")
    }
}
