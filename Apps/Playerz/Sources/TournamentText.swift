import Foundation
import PlayerzAPI

/// The web's words for tournaments (#22, `tournaments`).
enum TournamentText {
    static func format(_ format: Components.Schemas.Tournament.formatPayload) -> String {
        localized(key: "tournaments.format.\(format.rawValue)")
    }

    /// Its state; «Записването приключи» once registration has closed.
    static func status(_ tournament: Components.Schemas.Tournament) -> String {
        if tournament.status == .REGISTRATION, !tournament.entriesOpen {
            return String(localized: "tournaments.status.CLOSED")
        }
        return localized(key: "tournaments.status.\(tournament.status.rawValue)")
    }

    static func entry(_ status: Components.Schemas.MyTournamentEntry.statusPayload) -> String {
        localized(key: "tournaments.entry.\(status.rawValue)")
    }

    /// «Сингъл · Елиминации · Падел».
    static func kind(_ tournament: Components.Schemas.Tournament) -> String {
        let size = tournament.teamSize == ._2 ? String(localized: "tournaments.doubles") : String(localized: "tournaments.singles")
        return [size, format(tournament.format), GameText.sport(tournament.sport)].joined(separator: " · ")
    }

    /// «5 от 16 места», or pairs for doubles.
    static func places(_ tournament: Components.Schemas.Tournament) -> String {
        tournament.teamSize == ._2
            ? String(localized: "tournaments.placesPairs \(tournament.confirmed) \(tournament.drawSize)")
            : String(localized: "tournaments.places \(tournament.confirmed) \(tournament.drawSize)")
    }

    static func fee(_ tournament: Components.Schemas.Tournament) -> String {
        guard tournament.entryFeeCents > 0 else { return String(localized: "tournaments.free") }
        let fee = (Decimal(tournament.entryFeeCents) / 100).formatted(.currency(code: "EUR"))
        return tournament.feePayment == .ONLINE
            ? String(localized: "tournaments.feeOnline \(fee)")
            : String(localized: "tournaments.feeAtClub \(fee)")
    }

    /// When, on the venue's clock: one day, or from–to.
    static func dates(_ tournament: Components.Schemas.Tournament) -> String {
        let zone = tournament.venue?.timezone ?? "Europe/Sofia"
        let from = GameText.when(tournament.startsAt, timezone: zone)
        guard let end = tournament.endsAt else { return from }
        return String(localized: "tournaments.dates \(from) \(GameText.when(end, timezone: zone))")
    }

    static func person(_ person: Components.Schemas.TournamentPerson) -> String {
        person.deleted ? String(localized: "messages.deletedUser") : (person.name ?? String(localized: "tournaments.unnamed"))
    }

    static func error(_ code: String?) -> String {
        let known = [
            "TOURNAMENT_NOT_FOUND", "TOURNAMENT_NOT_OPEN", "TOURNAMENT_INVALID", "TOURNAMENT_ONLINE_FEE_UNAVAILABLE",
            "TOURNAMENT_ALREADY_ENTERED", "TOURNAMENT_PARTNER_REQUIRED", "TOURNAMENT_PARTNER_UNAVAILABLE",
            "TOURNAMENT_DRAW_FULL", "TOURNAMENT_ENTRY_NOT_FOUND", "TOURNAMENT_ENTRY_NOT_ACTIVE", "TOURNAMENT_STATE",
            "PLAYER_ACCOUNT_REQUIRED", "PHONE_REQUIRED", "RATE_LIMITED",
            "TOURNAMENT_MATCH_NOT_READY", "TOURNAMENT_MATCH_PLACED", "TOURNAMENT_NO_PROPOSAL", "SLOT_TAKEN",
            "SLOT_NOT_BOOKABLE", "NO_SHOW_BLOCKED", "BOOKING_LIMIT_REACHED", "TOURNAMENT_PAYMENT_NOT_DUE",
        ]
        guard let code, known.contains(code) else { return String(localized: "tournaments.error.FAILED") }
        return localized(key: "tournaments.error.\(code)")
    }
}
