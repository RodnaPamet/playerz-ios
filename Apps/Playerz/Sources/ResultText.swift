import Foundation
import PlayerzAPI

/// The web's words for results (#18, `results`).
enum ResultText {
    static func status(_ raw: String) -> String {
        ["REPORTED", "CONFIRMED", "REJECTED", "DECIDED", "VOIDED"].contains(raw)
            ? localized(key: "results.status.\(raw)")
            : raw
    }

    /// A refusal, by the server's code; anything else is the generic line.
    static func error(_ code: String?) -> String {
        let known = [
            "RESULT_NOT_REPORTABLE", "RESULT_ALREADY_REPORTED", "RESULT_NOT_AWAITING",
            "RESULT_NOT_YOURS_TO_ANSWER", "RESULT_NOT_FOUND", "INVALID_SIDES", "INVALID_SCORE",
            "RATE_LIMITED",
        ]
        guard let code, known.contains(code) else { return String(localized: "results.error.FAILED") }
        return localized(key: "results.error.\(code)")
    }

    /// A player's name; a deleted account has none.
    static func name(_ player: Components.Schemas.ResultPlayer) -> String {
        player.name ?? String(localized: "results.unnamed")
    }

    /// «Иван и Петър»: a side's players, in the reader's language.
    static func side(_ players: [Components.Schemas.ResultPlayer]) -> String {
        players.map(name).formatted(.list(type: .and))
    }
}
