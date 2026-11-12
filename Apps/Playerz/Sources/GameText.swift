import Foundation
import PlayerzAPI

/// The words Игри puts on screen (#510), as the web says them (#376).
enum GameText {
    /// A sport in the web's words; one added on the server after this build
    /// shows as the server wrote it (#34).
    static func sport(_ sport: String) -> String {
        let key = "sport.\(sport)"
        let text = localized(key: key)
        return text == key ? sport : text
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

    /// «съб, 14 ное», the day at the venue.
    static func day(_ date: Date, timezone: String) -> String {
        date.formatted(
            Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
                .weekday(.abbreviated).day().month(.abbreviated)
        )
    }

    /// «18:00 – 19:30», on the venue's clock.
    static func hours(_ start: Date, _ end: Date, timezone: String) -> String {
        let style = Date.FormatStyle(timeZone: TimeZone(identifier: timezone) ?? .current)
            .hour(.twoDigits(amPM: .omitted)).minute()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }

    /// «90 мин», from the booking's own start and end.
    static func duration(_ start: Date, _ end: Date) -> String {
        String(localized: "games.minutes \(Int((end.timeIntervalSince(start) / 60).rounded()))")
    }

    /// The game as one sentence, for VoiceOver.
    static func spoken(_ game: Components.Schemas.OpenGame, status: Components.Schemas.OpenGameRequestStatus? = nil) -> String {
        var parts = [
            sport(game.sport),
            when(game.startTs, timezone: game.timezone),
            duration(game.startTs, game.endTs),
            "\(game.venue.name), \(game.venue.city), \(game.courtName)",
        ]
        if let name = game.booker.firstName, !name.isEmpty {
            parts.append(String(localized: "games.card.organisedBy \(name)"))
        }
        parts.append(String(localized: "games.card.playersSpoken \(game.playersCount) \(game.capacity)"))
        if game.spotsLeft > 0 { parts.append(String(localized: "games.card.free \(game.spotsLeft)")) }
        parts.append(level(min: game.levelMin, max: game.levelMax))
        if game.viewer?.levelFits == true { parts.append(String(localized: "games.levelFits")) }
        if game.viewer?.isBooker == true { parts.append(String(localized: "games.yours")) }
        if let status { parts.append(self.status(status)) }
        return parts.joined(separator: ", ")
    }

    /// A picture's address; a relative one is read from the server it came from.
    static func picture(_ address: String?, server: String) -> URL? {
        guard let address, !address.isEmpty else { return nil }
        return URL(string: address, relativeTo: URL(string: server))?.absoluteURL
    }

    /// A day on the filter's strip: «Днес», «Утре», then «съб, 14 ное».
    static func filterDay(_ day: VenueDay, zone: String = "Europe/Sofia") -> String {
        if day.isToday { return String(localized: "venue.today") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        if calendar.isDateInTomorrow(day.start) { return String(localized: "games.filter.tomorrow") }
        return self.day(day.start, timezone: zone)
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
