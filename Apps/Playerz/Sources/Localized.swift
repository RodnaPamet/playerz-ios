import Foundation

/// The catalogue's string for a key built at runtime: `sport.PADEL`,
/// `games.status.PENDING`, a refusal's code.
///
/// The key must reach `LocalizationValue` as a plain `String`. Written as
/// `String.LocalizationValue("sport.\(x)")`, the interpolation is taken as a
/// format argument, so the key looked up is `sport.%@`. It matches nothing,
/// and the screen shows the raw key.
func localized(key: String) -> String {
    String(localized: String.LocalizationValue(key))
}
