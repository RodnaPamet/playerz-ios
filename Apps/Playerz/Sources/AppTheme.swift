import SwiftUI

/// The app's look (owner 2026-11-27): dark whatever the phone uses, unless
/// the person picks «Светла» or «Като телефона» in Профил. Kept on the
/// device: it is how this phone looks, not something the account carries.
enum AppTheme: String, CaseIterable, Sendable {
    case dark, light, system

    /// Where the choice is kept (`@AppStorage`).
    static let storageKey = "appTheme"

    /// What the whole app is drawn in; nil follows the phone.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }

    var label: String {
        switch self {
        case .dark: String(localized: "profile.theme.dark")
        case .light: String(localized: "profile.theme.light")
        case .system: String(localized: "profile.theme.system")
        }
    }
}
