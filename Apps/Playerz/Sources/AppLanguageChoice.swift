import Foundation
import os
import PlayerzAPI

/// The app's language: Bulgarian, unless the person chose English in
/// «Профил» (owner 2026-11-13). Until then the app followed the iPhone's
/// language (#13), so an iPhone set to English showed English, and the
/// audience is Bulgarian.
///
/// ═══ ONE SOURCE: THE APP'S OWN AppleLanguages ═══
///
/// iOS's per-app language (Settings → Playerz.bg → Language) is the key
/// `AppleLanguages` in the app's own defaults domain. The choice is kept
/// there too, so the two cannot disagree: a fresh install has none and gets
/// Bulgarian; the switch in «Профил» and the one in Settings both write it.
///
/// ═══ WHY THE APP HAS ITS OWN String(localized:) ═══
///
/// iOS settles which `.lproj` `Bundle.main` reads when the app starts, so a
/// choice made while it runs would show only after a restart. Every text in
/// the app is a `String(localized:)` call with no other argument; the overload
/// below, in this module, takes those calls and reads the CHOSEN language's
/// `.lproj` (`bundle`), from the moment it is chosen. What iOS draws itself
/// (a share sheet, a photo picker) follows at the next start, from
/// `AppleLanguages`.
enum AppLanguageChoice {
    private static let key = "AppleLanguages"

    /// The language chosen, Bulgarian where none is.
    static var current: AppLanguage.Code {
        let own = Bundle.main.bundleIdentifier
            .flatMap { UserDefaults.standard.persistentDomain(forName: $0) }?[key] as? [String]
        return AppLanguage.code(for: own?.first)
    }

    /// At launch, before the first text: the choice (or Bulgarian) in force.
    static func applyAtLaunch() {
        apply(current)
    }

    /// Kept for the next start and used from now on.
    static func apply(_ code: AppLanguage.Code) {
        UserDefaults.standard.set([code.rawValue], forKey: key)
        let lproj = Bundle.main.path(forResource: code.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
        chosen.withLock { $0 = Chosen(bundle: lproj ?? .main, locale: locale(code)) }
    }

    /// Where texts are read from, and how numbers inside them are written.
    /// Read from any thread (static text helpers are nonisolated), written on
    /// the main one.
    struct Chosen: @unchecked Sendable {
        let bundle: Bundle
        let locale: Locale
    }

    static let chosen = OSAllocatedUnfairLock(initialState: Chosen(bundle: .main, locale: .current))

    /// Dates and amounts in the chosen language, with Bulgaria's conventions.
    static func locale(_ code: AppLanguage.Code) -> Locale {
        Locale(identifier: code == .en ? "en_BG" : "bg_BG")
    }
}

extension String {
    /// The app's texts in the chosen language (AppLanguageChoice). Foundation's
    /// own initializer, called with the chosen `.lproj` and locale.
    init(localized value: String.LocalizationValue) {
        let chosen = AppLanguageChoice.chosen.withLock { $0 }
        self.init(localized: value, table: nil, bundle: chosen.bundle, locale: chosen.locale, comment: nil)
    }
}

// ═══ DATES AND NUMBERS IN THE CHOSEN LANGUAGE ═══
//
// A format style's locale defaults to the one iOS settled at launch, so a
// date written after a switch in «Профил» would stay in the old language
// next to texts in the new one. These take the app's `formatted` calls and
// give each style the chosen locale (`FormatStyle.locale(_:)`; a style with
// no language in it, ISO 8601, ignores it).

extension Date {
    func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date {
        format.locale(AppLanguageChoice.chosen.withLock { $0.locale }).format(self)
    }

    func formatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time))
    }

    /// Foundation's default: the date in numbers, the time short.
    func formatted() -> String {
        formatted(date: .numeric, time: .shortened)
    }
}

extension BinaryInteger {
    func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Self {
        format.locale(AppLanguageChoice.chosen.withLock { $0.locale }).format(self)
    }

    func formatted() -> String {
        formatted(IntegerFormatStyle<Self>())
    }
}

extension BinaryFloatingPoint {
    func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Self {
        format.locale(AppLanguageChoice.chosen.withLock { $0.locale }).format(self)
    }

    func formatted() -> String {
        formatted(FloatingPointFormatStyle<Self>())
    }
}

extension Decimal {
    func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Decimal {
        format.locale(AppLanguageChoice.chosen.withLock { $0.locale }).format(self)
    }

    func formatted() -> String {
        formatted(Decimal.FormatStyle())
    }
}

extension Sequence {
    func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Self {
        format.locale(AppLanguageChoice.chosen.withLock { $0.locale }).format(self)
    }
}
