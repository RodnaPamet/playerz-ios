import Foundation
import PlayerzAPI

/// The words the messaging screens put on screen (#484), as the web says them (#375).
enum ConversationText {
    /// Who the conversation is with: a player (or «Изтрит потребител»), a club,
    /// or a game chat named after its venue and time.
    static func title(_ counterpart: Components.Schemas.ConversationCounterpart) -> String {
        switch counterpart {
        case .case1(let player):
            player.deleted
                ? String(localized: "messages.deletedUser")
                : (player.name ?? String(localized: "messages.unnamed"))
        case .case2(let club):
            club.name
        case .case3(let game):
            "\(game.venueName) · \(GameText.when(game.startTs, timezone: game.timezone))"
        }
    }

    static func preview(_ last: Components.Schemas.ConversationSummary.lastMessagePayload?) -> String {
        guard let last else { return "" }
        if last.deleted { return String(localized: "messages.retracted") }
        let text = last.preview ?? ""
        return last.mine ? String(localized: "messages.you \(text)") : text
    }

    /// A refusal the server named, in the user's words; the generic line otherwise.
    static func error(_ code: String?) -> String {
        let known: Set<String> = [
            "MESSAGE_TOO_LONG", "CONVERSATION_BLOCKED", "CONVERSATION_NOT_FOUND", "RECIPIENT_GONE",
            "REQUEST_PENDING", "RATE_LIMITED", "PLAYER_NOT_FOUND", "CLUB_NOT_FOUND",
            "PLAYER_ACCOUNT_REQUIRED", "CANNOT_MESSAGE_SELF",
        ]
        guard let code, known.contains(code) else { return String(localized: "messages.error.generic") }
        return localized(key: "messages.error.\(code)")
    }
}
