import Foundation
import OpenAPIRuntime

/// Where the question was asked from (`page`): identifiers only, never a
/// title or anything typed, since the server reads it into the prompt.
public struct AssistantPage: Equatable, Hashable, Sendable {
    public enum Screen: String, Sendable {
        case home, venues, venue, bookings, booking, games, game, profile, messages, other
    }

    public var screen: Screen
    public var venueId: String?
    public var bookingId: String?
    public var gameId: String?

    public init(_ screen: Screen, venueId: String? = nil, bookingId: String? = nil, gameId: String? = nil) {
        self.screen = screen
        self.venueId = venueId
        self.bookingId = bookingId
        self.gameId = gameId
    }

    public static func venue(_ id: String) -> Self { .init(.venue, venueId: id) }
    public static func booking(_ id: String) -> Self { .init(.booking, bookingId: id) }
    public static func game(_ id: String) -> Self { .init(.game, gameId: id) }

    var wire: Components.Schemas.AssistantPage {
        .init(screen: .init(rawValue: screen.rawValue) ?? .other, venueId: venueId, bookingId: bookingId, gameId: gameId)
    }
}

/// One question.
public struct AssistantAsk: Equatable, Sendable {
    /// 1–2000 characters, as typed.
    public var message: String
    /// The conversation from the turn before, to continue it; nil for a new one.
    public var conversationId: String?
    public var page: AssistantPage?
    /// Only where the app already may read it: never asked for this.
    public var location: (lat: Double, lng: Double)?

    public static let maxLength = 2000

    public init(
        message: String, conversationId: String? = nil, page: AssistantPage? = nil,
        location: (lat: Double, lng: Double)? = nil
    ) {
        self.message = message
        self.conversationId = conversationId
        self.page = page
        self.location = location
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.message == b.message && a.conversationId == b.conversationId && a.page == b.page
            && a.location?.lat == b.location?.lat && a.location?.lng == b.location?.lng
    }

    var wire: Components.Schemas.AssistantAskRequest {
        .init(
            message: String(message.prefix(Self.maxLength)),
            conversationId: conversationId,
            page: page?.wire,
            location: location.map { .init(lat: $0.lat, lng: $0.lng) }
        )
    }
}

/// A question refused before the stream opened (an ordinary JSON error).
public enum AssistantAskError: Error, Equatable, Sendable {
    /// 404 `ASSISTANT_DISABLED`: switched off on this server. Hide the launcher.
    case disabled
    /// 403 `ASSISTANT_PLAYERS_ONLY`: not for this account. Hide the launcher.
    case playersOnly
    /// 429: twenty questions in ten minutes.
    case rateLimited
    /// 400: the question itself (empty, too long) or what came with it.
    case badRequest
    /// 401: the session is gone.
    case signedOut
    /// Anything else, the server's message with it when it sent one.
    case failed(message: String?)
}

/// The assistant's routes, through the generated client: the session's token
/// and base URL come with it (`BearerMiddleware`).
public enum AssistantAPI {
    /// One turn, as its events arrive.
    ///
    /// The generated client hands the `text/event-stream` body over as it
    /// streams (URLSessionTransport streams on Apple platforms), and the
    /// runtime's SSE reader splits it into events, `: keep-alive` comments
    /// skipped. Each `data:` payload is then read as an `AssistantEvent`; one
    /// that does not read is skipped.
    public static func ask(_ ask: AssistantAsk, client: Client) async throws -> AsyncThrowingStream<AssistantEvent, Error> {
        let response = try await client.askAssistant(body: .json(ask.wire))
        switch response {
        case let .ok(ok):
            return events(try ok.body.text_event_hyphen_stream)
        case .badRequest: throw AssistantAskError.badRequest
        case .unauthorized: throw AssistantAskError.signedOut
        case .tooManyRequests: throw AssistantAskError.rateLimited
        case .forbidden:
            // Any 403 here is "not for this account": players only.
            throw AssistantAskError.playersOnly
        case .notFound: throw AssistantAskError.disabled
        default:
            throw AssistantAskError.failed(message: errorMessage(response))
        }
    }

    /// The events in an SSE body.
    public static func events(_ body: HTTPBody) -> AsyncThrowingStream<AssistantEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<AssistantEvent, Error>.makeStream()
        let reading = Task {
            do {
                for try await event in body.asDecodedServerSentEvents() {
                    guard let payload = event.data, let decoded = AssistantEvent.decode(payload) else { continue }
                    continuation.yield(decoded)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in reading.cancel() }
        return stream
    }

    /// Whether this server offers the assistant: `GET /me/assistant-memory`
    /// answers 404 `ASSISTANT_DISABLED` while it is off, and is readable while
    /// only the memory is off. Nil when it could not be told (offline, a
    /// failure): the caller keeps what it knew.
    public static func isOffered(client: Client) async -> Bool? {
        guard let response = try? await client.listAssistantMemory() else { return nil }
        switch response {
        case .ok: return true
        case .notFound: return false
        default: return nil
        }
    }

    // MARK: - «Какво помни асистентът»

    public static func points(client: Client) async throws -> [AssistantMemory.Point] {
        switch try await client.listAssistantMemory() {
        case let .ok(ok): return try ok.body.json.data.items.map(AssistantMemory.Point.init)
        case let other: throw AssistantMemoryError(other)
        }
    }

    /// Forget one. One already gone is what was asked for.
    public static func forgetPoint(_ id: String, client: Client) async throws {
        switch try await client.forgetAssistantMemoryPoint(path: .init(id: id)) {
        case .noContent: return
        case let .notFound(refused) where (try? refused.body.json.error.code) == "MEMORY_POINT_NOT_FOUND": return
        case let other: throw AssistantMemoryError(other)
        }
    }

    public static func forgetAllPoints(client: Client) async throws {
        switch try await client.forgetAllAssistantMemory() {
        case .ok: return
        case let other: throw AssistantMemoryError(other)
        }
    }

    /// The person's own words, which the assistant then never rewrites.
    public static func editPoint(_ id: String, text: String, client: Client) async throws -> AssistantMemory.Point {
        switch try await client.editAssistantMemoryPoint(path: .init(id: id), body: .json(.init(text: text))) {
        case let .ok(ok): return AssistantMemory.Point(try ok.body.json.data)
        case let other: throw AssistantMemoryError(other)
        }
    }

    // MARK: - Past conversations

    public static func conversations(client: Client) async throws -> [AssistantMemory.Conversation] {
        switch try await client.listAssistantConversations() {
        case let .ok(ok): return try ok.body.json.data.items.map(AssistantMemory.Conversation.init)
        case let other: throw AssistantMemoryError(other)
        }
    }

    public static func conversation(_ id: String, client: Client) async throws -> AssistantMemory.Transcript {
        switch try await client.getAssistantConversation(path: .init(id: id)) {
        case let .ok(ok): return AssistantMemory.Transcript(try ok.body.json.data)
        case let other: throw AssistantMemoryError(other)
        }
    }

    /// Delete one. Gone already, or never this person's, is what was asked for.
    public static func deleteConversation(_ id: String, client: Client) async throws {
        switch try await client.deleteAssistantConversation(path: .init(id: id)) {
        case .noContent: return
        case let .notFound(refused) where (try? refused.body.json.error.code) == "ASSISTANT_CONVERSATION_NOT_FOUND": return
        case let other: throw AssistantMemoryError(other)
        }
    }

    public static func deleteAllConversations(client: Client) async throws {
        switch try await client.deleteAllAssistantConversations() {
        case .ok: return
        case let other: throw AssistantMemoryError(other)
        }
    }

    /// The `message` of an error envelope in any generated response.
    static func errorMessage(_ output: Any) -> String? {
        errorEnvelope(output)?.message
    }

    static func errorEnvelope(_ output: Any) -> Components.Schemas._Error.errorPayload? {
        for response in Mirror(reflecting: output).children {
            for field in Mirror(reflecting: response.value).children where field.label == "body" {
                for body in Mirror(reflecting: field.value).children {
                    if let envelope = body.value as? Components.Schemas._Error { return envelope.error }
                }
            }
        }
        return nil
    }
}

/// A memory or conversations call refused.
public enum AssistantMemoryError: Error, Equatable, Sendable {
    /// `ASSISTANT_DISABLED`: switched off on this server.
    case disabled
    /// The point or conversation is gone (forgotten elsewhere).
    case notFound
    /// `MEMORY_POINT_EMPTY`, or nothing typed.
    case empty
    case rateLimited
    case signedOut
    case failed

    init(_ output: Any) {
        let envelope = AssistantAPI.errorEnvelope(output)
        switch envelope?.code {
        case "ASSISTANT_DISABLED": self = .disabled
        case "MEMORY_POINT_NOT_FOUND", "ASSISTANT_CONVERSATION_NOT_FOUND": self = .notFound
        case "MEMORY_POINT_EMPTY": self = .empty
        case "RATE_LIMITED": self = .rateLimited
        case "UNAUTHORIZED": self = .signedOut
        default: self = .failed
        }
    }
}
