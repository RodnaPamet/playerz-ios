import Foundation

/// One event of a turn of «Асистент» (`POST /assistant/stream`, projectZ#704):
/// one `data:` line, named by its own `type`. There is no `event:` field to
/// subscribe to, so a type this build does not know decodes as `.unknown` and
/// is ignored: an older phone keeps working against a newer server.
///
/// In order: `conversation`, `thinking`, any `tool_call`/`tool_result`, then
/// `answer` or `refusal`, maybe `halt`, and `done` always last. There is no
/// `error` event, by design: a connection that closes before `done` is a
/// transport failure and nothing else.
///
/// Decoded by hand rather than through the generated `AssistantStreamEvent`:
/// that one is a `oneOf`, and one field it does not expect would cost the
/// whole event. Here an odd field costs that field.
public enum AssistantEvent: Decodable, Equatable, Sendable {
    /// First, before any work: the conversation the question was filed under.
    /// Sent back with the next question to continue it.
    case conversation(id: String)
    case thinking
    case toolCall(name: String)
    case toolResult(name: String, ok: Bool, truncated: Bool)
    /// The whole answer, once. `proposal` is a draft nothing has written.
    case answer(text: String, proposal: AssistantProposal?)
    /// No answer, and not a fault: the reason as a CODE, and the server's
    /// sentence for it in the account's language.
    case refusal(code: String, message: String?)
    /// After an answer: it is incomplete. With none before it: the model
    /// could not be used, or today's limit is reached.
    case halt(code: String, message: String?)
    /// Always last, after a halt too.
    case done(truncatedAny: Bool, partialAny: Bool)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type, conversationId, name, ok, truncated, text, proposal, code, message, truncatedAny, partialAny
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "conversation":
            // No id is a frame this phone cannot use: read as unknown, so it
            // costs the follow-up, never the answer.
            if let id = try? c.decode(String.self, forKey: .conversationId), !id.isEmpty {
                self = .conversation(id: id)
            } else {
                self = .unknown(type: type)
            }
        case "thinking":
            self = .thinking
        case "tool_call":
            self = .toolCall(name: (try? c.decode(String.self, forKey: .name)) ?? "")
        case "tool_result":
            self = .toolResult(
                name: (try? c.decode(String.self, forKey: .name)) ?? "",
                ok: (try? c.decode(Bool.self, forKey: .ok)) ?? false,
                truncated: (try? c.decode(Bool.self, forKey: .truncated)) ?? false
            )
        case "answer":
            // A proposal that does not read costs the button, never the answer.
            self = .answer(
                text: try c.decode(String.self, forKey: .text),
                proposal: (try? c.decodeIfPresent(AssistantProposal.self, forKey: .proposal)) ?? nil
            )
        case "refusal":
            self = .refusal(
                code: (try? c.decode(String.self, forKey: .code)) ?? "",
                message: (try? c.decodeIfPresent(String.self, forKey: .message)) ?? nil
            )
        case "halt":
            self = .halt(
                code: (try? c.decode(String.self, forKey: .code)) ?? "",
                message: (try? c.decodeIfPresent(String.self, forKey: .message)) ?? nil
            )
        case "done":
            self = .done(
                truncatedAny: (try? c.decode(Bool.self, forKey: .truncatedAny)) ?? false,
                partialAny: (try? c.decode(Bool.self, forKey: .partialAny)) ?? false
            )
        default:
            self = .unknown(type: type)
        }
    }

    /// One `data:` payload. Nil for one that is not an event at all: skipped,
    /// as an unknown type is, so one odd line never ends a turn.
    public static func decode(_ payload: String) -> AssistantEvent? {
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AssistantEvent.self, from: data)
    }
}

/// A booking or a game the assistant PREPARED: the app opens its own booking
/// screen filled with it, and the person confirms there. Nothing is written
/// before that; the assistant never books.
///
/// `booking`: the reservation summary of `venueId`, with the court and the
/// hours. `game`: the same booking, then the game opened on it with `spots`
/// and the levels. A kind this build does not know is no proposal at all.
public struct AssistantProposal: Decodable, Equatable, Sendable {
    public enum Kind: String, Sendable { case booking, game }

    public let kind: Kind
    public let venueId: String
    /// The court.
    public let resourceId: String
    public let start: Date
    public let end: Date
    /// `game` only: how many more players the game asks for.
    public let spots: Int?
    /// `game` only; nil when open to any level.
    public let levelMin: Int?
    public let levelMax: Int?

    public init(
        kind: Kind, venueId: String, resourceId: String, start: Date, end: Date,
        spots: Int? = nil, levelMin: Int? = nil, levelMax: Int? = nil
    ) {
        self.kind = kind
        self.venueId = venueId
        self.resourceId = resourceId
        self.start = start
        self.end = end
        self.spots = spots
        self.levelMin = levelMin
        self.levelMax = levelMax
    }

    private enum CodingKeys: String, CodingKey { case kind, draft }
    private enum DraftKeys: String, CodingKey { case venueId, resourceId, startTs, endTs, spots, levelMin, levelMax }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let kind = Kind(rawValue: try c.decode(String.self, forKey: .kind)) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown kind")
        }
        let d = try c.nestedContainer(keyedBy: DraftKeys.self, forKey: .draft)
        guard let start = Self.instant(try d.decode(String.self, forKey: .startTs)),
              let end = Self.instant(try d.decode(String.self, forKey: .endTs)),
              end > start
        else {
            throw DecodingError.dataCorruptedError(forKey: .startTs, in: d, debugDescription: "unreadable hours")
        }
        self.kind = kind
        venueId = try d.decode(String.self, forKey: .venueId)
        resourceId = try d.decode(String.self, forKey: .resourceId)
        self.start = start
        self.end = end
        spots = (try? d.decodeIfPresent(Int.self, forKey: .spots)) ?? nil
        levelMin = (try? d.decodeIfPresent(Int.self, forKey: .levelMin)) ?? nil
        levelMax = (try? d.decodeIfPresent(Int.self, forKey: .levelMax)) ?? nil
    }

    /// The server writes `toISOString()`, with milliseconds; without them
    /// reads too, as `ServerDateTranscoder` reads every other date.
    static func instant(_ text: String) -> Date? {
        try? ServerDateTranscoder().decode(text)
    }
}
