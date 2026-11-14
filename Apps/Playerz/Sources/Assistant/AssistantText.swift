import Foundation
import PlayerzAPI

/// Every word the assistant's sheet says that the model does not. The
/// stream carries CODES for its refusals and stops; each has its sentence
/// here, and the server's own sentence is shown instead only when it is in
/// the app's language (`ServerSentence`).
enum AssistantText {
    static var title: String { String(localized: "assistant.title") }
    static var prompt: String { String(localized: "assistant.prompt") }
    static var intro: String { String(localized: "assistant.intro") }
    static var ask: String { String(localized: "assistant.ask") }
    static var newConversation: String { String(localized: "assistant.newConversation") }
    static var earlierQuestion: String { String(localized: "assistant.earlierQuestion") }
    static var earlierLeftOut: String { String(localized: "assistant.earlierLeftOut") }

    static func you(_ question: String) -> String { String(localized: "assistant.you \(question)") }
    static func answered(_ text: String) -> String { String(localized: "assistant.answered \(text)") }

    // MARK: - While a turn runs

    static func work(_ work: AssistantStore.Work) -> String {
        switch work {
        case .thinking: String(localized: "assistant.thinking")
        case .writing: String(localized: "assistant.writing")
        case let .reading(tool):
            // The data being read, by the tool's name, so a long wait reads
            // as work being done; a tool this build does not know is the
            // general sentence.
            switch tool {
            case "find_free_places": String(localized: "assistant.reading.find_free_places")
            case "best_time_for_game": String(localized: "assistant.reading.best_time_for_game")
            case "propose_booking": String(localized: "assistant.reading.propose_booking")
            case "search_past_conversations": String(localized: "assistant.reading.search_past_conversations")
            default: String(localized: "assistant.reading")
            }
        }
    }

    // MARK: - How a turn ended

    static func refusal(_ code: String) -> String {
        switch code {
        case "ASSISTANT_NO_GROUNDING": String(localized: "assistant.refusal.ASSISTANT_NO_GROUNDING")
        case "ASSISTANT_EGRESS_BLOCKED": String(localized: "assistant.refusal.ASSISTANT_EGRESS_BLOCKED")
        case "ASSISTANT_DECLINED": String(localized: "assistant.refusal.ASSISTANT_DECLINED")
        default: String(localized: "assistant.refusal.other")
        }
    }

    static func halt(_ code: String) -> String {
        switch code {
        case "ASSISTANT_TOOL_BUDGET": String(localized: "assistant.halt.ASSISTANT_TOOL_BUDGET")
        case "ASSISTANT_TIME_BUDGET": String(localized: "assistant.halt.ASSISTANT_TIME_BUDGET")
        case "ASSISTANT_SPEND_CEILING": String(localized: "assistant.halt.ASSISTANT_SPEND_CEILING")
        case "ASSISTANT_PROVIDER_UNAVAILABLE": String(localized: "assistant.halt.ASSISTANT_PROVIDER_UNAVAILABLE")
        case "ASSISTANT_REQUEST_REJECTED": String(localized: "assistant.halt.ASSISTANT_REQUEST_REJECTED")
        case "ASSISTANT_TRUNCATED_RESULT": String(localized: "assistant.halt.ASSISTANT_TRUNCATED_RESULT")
        case "ASSISTANT_PARTIAL_DATA": String(localized: "assistant.halt.ASSISTANT_PARTIAL_DATA")
        default: String(localized: "assistant.halt.other")
        }
    }

    static func note(_ note: AssistantStore.Note) -> String {
        switch note {
        case let .halt(code, message): said(message, else: halt(code))
        case .partial: halt("ASSISTANT_PARTIAL_DATA")
        case .truncated: halt("ASSISTANT_TRUNCATED_RESULT")
        }
    }

    static func ending(_ ending: AssistantStore.Ending) -> String {
        switch ending {
        case let .refusal(code, message): said(message, else: refusal(code))
        case let .halt(code, message): said(message, else: halt(code))
        case .noAnswer: String(localized: "assistant.noAnswer")
        case .interrupted: String(localized: "assistant.interrupted")
        case .lostMidAnswer: String(localized: "assistant.lostMidAnswer")
        case .offline: String(localized: "assistant.offline")
        case .answerNotKept: String(localized: "assistant.answerNotKept")
        case let .refused(refused):
            switch refused {
            case .disabled: String(localized: "assistant.refused.disabled")
            case .playersOnly: String(localized: "assistant.refused.playersOnly")
            case .rateLimited: String(localized: "assistant.refused.rateLimited")
            case .badRequest: String(localized: "assistant.refused.badRequest")
            case .signedOut: String(localized: "assistant.refused.signedOut")
            case let .failed(message): said(message, else: String(localized: "assistant.refused.failed"))
            }
        }
    }

    /// The server's own sentence, when it is in the app's language; ours otherwise.
    static func said(_ message: String?, else copy: String) -> String {
        ServerSentence.fits(message, bulgarian: AppLanguageChoice.current == .bg) ? message ?? copy : copy
    }

    // MARK: - A prepared booking or game

    static func open(_ kind: AssistantProposal.Kind) -> String {
        switch kind {
        case .booking: String(localized: "assistant.proposal.booking")
        case .game: String(localized: "assistant.proposal.game")
        }
    }

    static var preparedNote: String { String(localized: "assistant.proposal.note") }
    static var gone: String { String(localized: "assistant.proposal.gone") }
    static var goneHint: String { String(localized: "assistant.proposal.goneHint") }
    static var openVenue: String { String(localized: "assistant.proposal.openVenue") }
}

/// «Какво помни асистентът»'s words.
enum AssistantMemoryText {
    static var title: String { String(localized: "assistant.memory.title") }
    static var rowHint: String { String(localized: "assistant.memory.rowHint") }
    static var listTitle: String { String(localized: "assistant.memory.list") }
    static var listNote: String { String(localized: "assistant.memory.listNote") }
    static var emptyTitle: String { String(localized: "assistant.memory.empty") }
    static var emptyNote: String { String(localized: "assistant.memory.emptyNote") }
    static func rememberedOn(_ day: String) -> String { String(localized: "assistant.memory.rememberedOn \(day)") }
    static var editedByYou: String { String(localized: "assistant.memory.editedByYou") }
    static var editTitle: String { String(localized: "assistant.memory.editTitle") }
    static var editPlaceholder: String { String(localized: "assistant.memory.editPlaceholder") }
    static func editCount(_ count: Int, _ limit: Int) -> String {
        String(localized: "assistant.memory.editCount \(count) \(limit)")
    }
    static var editHint: String { String(localized: "assistant.memory.editHint") }
    static var save: String { String(localized: "assistant.memory.save") }
    static var cancel: String { String(localized: "assistant.memory.cancel") }
    static var delete: String { String(localized: "assistant.memory.delete") }
    static var undo: String { String(localized: "assistant.memory.undo") }
    static var retry: String { String(localized: "venues.retry") }
    static func forgotten(_ point: AssistantMemory.Point) -> String {
        String(localized: "assistant.memory.forgotten \(point.text)")
    }
    static var forgottenSaid: String { String(localized: "assistant.memory.forgottenSaid") }
    static var forgetAll: String { String(localized: "assistant.memory.forgetAll") }
    static var forgetAllQuestion: String { String(localized: "assistant.memory.forgetAllQuestion") }
    static var forgetAllNote: String { String(localized: "assistant.memory.forgetAllNote") }
    static var notForgotten: String { String(localized: "assistant.memory.notForgotten") }

    static var conversationsTitle: String { String(localized: "assistant.conversations.title") }
    static var conversationsNote: String { String(localized: "assistant.conversations.note") }
    static var noConversations: String { String(localized: "assistant.conversations.empty") }
    static var noConversationsNote: String { String(localized: "assistant.conversations.emptyNote") }
    static var noOpening: String { String(localized: "assistant.conversations.noOpening") }
    static func turns(_ count: Int) -> String { String(localized: "assistant.conversations.turns \(count)") }
    static var openHint: String { String(localized: "assistant.conversations.openHint") }
    static func deleted(_ conversation: AssistantMemory.Conversation) -> String {
        conversation.opening.map { String(localized: "assistant.conversations.deleted \($0)") }
            ?? String(localized: "assistant.conversations.deletedNoOpening")
    }
    static var deleteAll: String { String(localized: "assistant.conversations.deleteAll") }
    static var deleteAllQuestion: String { String(localized: "assistant.conversations.deleteAllQuestion") }
    static var deleteAllNote: String { String(localized: "assistant.conversations.deleteAllNote") }

    static func problem(_ problem: AssistantMemoryError) -> String {
        switch problem {
        case .disabled: String(localized: "assistant.refused.disabled")
        case .notFound: String(localized: "assistant.memory.error.notFound")
        case .empty: String(localized: "assistant.memory.error.empty")
        case .rateLimited: String(localized: "assistant.memory.error.rateLimited")
        case .signedOut: String(localized: "assistant.refused.signedOut")
        case .failed: String(localized: "assistant.memory.error.failed")
        }
    }
}
