import Foundation
import PlayerzAPI

/// The words Игри puts on screen (#510), as the web says them (#376).
enum GameText {
    static func sport(_ sport: Components.Schemas.SportType) -> String {
        localized(key: "sport.\(sport.rawValue)")
    }

    static func status(_ status: Components.Schemas.OpenGameRequestStatus) -> String {
        localized(key: "games.status.\(status.rawValue)")
    }

    /// The level wish, which is a wish and not a rule (#376).
    static func level(min: Int?, max: Int?) -> String {
        switch (min, max) {
        case (nil, nil):
            String(localized: "games.level.any")
        case let (lo?, hi?) where lo == hi:
            String(localized: "games.level.one \(lo)")
        case let (lo?, hi?):
            String(localized: "games.level.range \(lo) \(hi)")
        case let (lo?, nil):
            String(localized: "games.level.from \(lo)")
        case let (nil, hi?):
            String(localized: "games.level.to \(hi)")
        }
    }

    /// «пт, 17 окт., 19:00», on the VENUE's clock: a game at a Sofia club is at
    /// 19:00 for everyone, wherever the phone thinks it is.
    static func when(_ date: Date, timezone: String) -> String {
        date.formatted(
            Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
                .weekday(.abbreviated).day().month(.abbreviated)
                .hour(.twoDigits(amPM: .omitted)).minute()
        )
    }

    /// A refusal the server named, in the user's words; the generic line for
    /// anything else.
    static func error(_ code: String?) -> String {
        // The phone step opens over the screen (#11); this says why.
        if code == "PHONE_REQUIRED" { return String(localized: "phone.required.title") }
        let known: Set<String> = [
            "GAME_FULL", "GAME_CLOSED", "GAME_NOT_FOUND", "OPEN_PLAY_CUTOFF_PASSED",
            "ASK_DECLINED", "ALREADY_PLAYING", "PLAYER_ACCOUNT_REQUIRED", "NO_SHOW_BLOCKED",
            "PHONE_REQUIRED", "RATE_LIMITED", "REQUEST_NOT_PENDING", "SPOTS_UNAVAILABLE",
            "NOTE_TOO_LONG",
        ]
        guard let code, known.contains(code) else { return String(localized: "games.error.generic") }
        return localized(key: "games.error.\(code)")
    }
}
