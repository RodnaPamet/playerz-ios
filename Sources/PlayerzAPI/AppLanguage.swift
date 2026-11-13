/// The app's language as the account stores it (playerz-ios#13).
///
/// Bulgarian unless chosen otherwise, in the app's «Профил» or in iOS
/// Settings → Playerz.bg → Language (owner 2026-11-13; the app's
/// AppLanguageChoice). The account's `locale` decides the language of its
/// emails and pushes, so the app writes the language it is showing.
public enum AppLanguage {
    public typealias Code = Components.Schemas.UpdateMeRequest.localePayload

    /// The account's code for the localization iOS chose for the app
    /// (`Bundle.main.preferredLocalizations.first`): English, or Bulgarian,
    /// which the app is written in and falls back to.
    public static func code(for localization: String?) -> Code {
        localization?.lowercased().hasPrefix("en") == true ? .en : .bg
    }
}
