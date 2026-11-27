import Foundation
import Observation
import OpenAPIRuntime

/// What keeps a turn's connection up while the person steps out of the app:
/// a background task in the app (`AssistantKeepAlive` there), nothing in
/// tests.
@MainActor
public protocol AssistantConnectionHold: AnyObject {
    func begin()
    func end()
}

/// The assistant's conversation in its sheet: each question a turn, shown
/// for as long as the sheet's store lives, and continued on the server by
/// its id (`conversationId`), never by sending earlier turns back.
///
/// The phases carry CODES, not sentences: the app says them in the person's
/// language (`AssistantText`), so every decision here is testable without a
/// screen.
@MainActor
@Observable
public final class AssistantStore {
    public struct Turn: Identifiable, Equatable, Sendable {
        public let id = UUID()
        /// The question; nil for an answer whose question a past
        /// conversation left out (its oldest turns go first).
        public let question: String?
        public var phase: Phase

        public init(question: String?, phase: Phase) {
            self.question = question
            self.phase = phase
        }

        public var isWorking: Bool {
            if case .working = phase { return true }
            return false
        }
    }

    public enum Phase: Equatable, Sendable {
        /// Running: what it is doing.
        case working(Work)
        /// The answer, the draft it prepared, and what stopped it short.
        case answered(String, proposal: AssistantProposal? = nil, notes: [Note] = [])
        /// Refused or failed: why.
        case unanswered(Ending)
    }

    public enum Work: Equatable, Sendable {
        case thinking
        /// A tool is running, by its name (`find_free_places`…).
        case reading(String)
        /// Read; the answer is being written.
        case writing
    }

    /// What makes an answer incomplete.
    public enum Note: Equatable, Sendable {
        case halt(code: String, message: String?)
        /// `done.partialAny`: some read did not gather everything.
        case partial
        /// `done.truncatedAny`: some list was shortened.
        case truncated
    }

    public enum Ending: Equatable, Sendable {
        case refusal(code: String, message: String?)
        /// A halt with no answer before it.
        case halt(code: String, message: String?)
        /// `done` with nothing before it.
        case noAnswer
        /// Closed with no `done`: the transport, nothing else; or stopped.
        case interrupted
        /// The network went while the answer was coming.
        case lostMidAnswer
        /// Refused before the stream opened.
        case refused(AssistantAskError)
        /// The server could not be reached at all.
        case offline
        /// A past conversation's question with no answer kept.
        case answerNotKept
    }

    public typealias Asker = @MainActor (AssistantAsk) async throws -> AsyncThrowingStream<AssistantEvent, Error>

    public private(set) var turns: [Turn] = []
    public var draft = ""
    /// A turn's stream is open: from the question until `done` (past the
    /// answer, which comes before a `halt`).
    public private(set) var asking = false
    /// The server's conversation, once it has named one: sent with every next
    /// question until «Нов разговор».
    public private(set) var conversationId: String?
    /// A past conversation opened with its oldest turns left out.
    public private(set) var earlierLeftOut = false
    /// The server said the assistant is not offered here (off, or not for
    /// this account): the app hides its button.
    public private(set) var unavailable: AssistantAskError?

    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private let asker: Asker
    @ObservationIgnored private let hold: AssistantConnectionHold?

    public init(ask: @escaping Asker, hold: AssistantConnectionHold? = nil) {
        self.asker = ask
        self.hold = hold
    }

    public var canSend: Bool {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !asking && !question.isEmpty && question.count <= AssistantAsk.maxLength
    }

    /// The draft as a question, asked from where the person is.
    public func send(page: AssistantPage? = nil, location: (lat: Double, lng: Double)? = nil) {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        draft = ""
        asking = true
        turns.append(Turn(question: question, phase: .working(.thinking)))
        let index = turns.count - 1
        let ask = AssistantAsk(message: question, conversationId: conversationId, page: page, location: location)
        running = Task { await run(ask, at: index) }
    }

    /// «Нов разговор»: the next question starts a fresh conversation, and the
    /// sheet clears. Nothing is deleted: the server keeps every exchange.
    public func newConversation() {
        stop()
        turns = []
        conversationId = nil
        earlierLeftOut = false
    }

    /// A past conversation, opened from «Минали разговори»: its turns on
    /// screen, and the next question continues it.
    public func resume(_ past: AssistantMemory.Transcript) {
        stop()
        turns = Self.turns(from: past.items)
        conversationId = past.id
        earlierLeftOut = past.truncated
    }

    /// A transcript as turns: each question with the answer after it. A
    /// question with none says the answer was not kept; an answer whose
    /// question was left out stands with no question.
    public nonisolated static func turns(from items: [AssistantMemory.Transcript.Item]) -> [Turn] {
        var turns: [Turn] = []
        for item in items {
            switch item.role {
            case .user:
                turns.append(Turn(question: item.text, phase: .unanswered(.answerNotKept)))
            case .assistant:
                if let last = turns.indices.last, turns[last].phase == .unanswered(.answerNotKept) {
                    turns[last].phase = .answered(item.text)
                } else {
                    turns.append(Turn(question: nil, phase: .answered(item.text)))
                }
            }
        }
        return turns
    }

    /// The running turn, to its end. For the tests, which must not race it.
    public func settled() async {
        await running?.value
    }

    /// The sheet closed or the person stopped it: nothing more arrives, and a
    /// turn cut short says so.
    public func stop() {
        running?.cancel()
        running = nil
        asking = false
        hold?.end()
        if let last = turns.indices.last, turns[last].isWorking {
            turns[last].phase = .unanswered(.interrupted)
        }
    }

    func run(_ ask: AssistantAsk, at index: Int) async {
        hold?.begin()
        // A turn that was stopped has already given the hold back and ended
        // `asking` (`stop`); ending them again here would end the NEXT turn's,
        // which may have begun while this one unwound.
        defer {
            if !Task.isCancelled {
                hold?.end()
                asking = false
            }
        }
        var opened = false
        var answer: (text: String, proposal: AssistantProposal?)?
        // The halt that was said, if any: `done` follows it and may add what
        // the halt did not say.
        var halted: (code: String, message: String?)?
        do {
            let events = try await asker(ask)
            opened = true
            for try await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case let .conversation(id):
                    conversationId = id
                case .thinking:
                    if answer == nil { turns[index].phase = .working(.thinking) }
                case let .toolCall(name):
                    if answer == nil { turns[index].phase = .working(.reading(name)) }
                case .toolResult:
                    // Read; the model writes next, unless it asks for more.
                    if answer == nil { turns[index].phase = .working(.writing) }
                case let .answer(text, proposal):
                    answer = (text, proposal)
                    turns[index].phase = .answered(text, proposal: proposal)
                case let .refusal(code, message):
                    turns[index].phase = .unanswered(.refusal(code: code, message: message))
                    // `done` still follows; nothing after a refusal changes it.
                    halted = (code, message)
                    answer = nil
                case let .halt(code, message):
                    if case .unanswered(.refusal) = turns[index].phase { continue }
                    halted = (code, message)
                    if let answer {
                        turns[index].phase = .answered(
                            answer.text, proposal: answer.proposal, notes: [.halt(code: code, message: message)])
                    } else {
                        turns[index].phase = .unanswered(.halt(code: code, message: message))
                    }
                case let .done(truncatedAny, partialAny):
                    if case .unanswered(.refusal) = turns[index].phase { return }
                    if let answer {
                        var notes: [Note] = halted.map { [.halt(code: $0.code, message: $0.message)] } ?? []
                        // A turn that was partial AND ran out of time is
                        // halted for the time; the partial fact rides on
                        // `done` and is said too.
                        if partialAny, halted?.code != "ASSISTANT_PARTIAL_DATA" { notes.append(.partial) }
                        if truncatedAny, halted?.code != "ASSISTANT_TRUNCATED_RESULT" { notes.append(.truncated) }
                        turns[index].phase = .answered(answer.text, proposal: answer.proposal, notes: notes)
                    } else if halted == nil {
                        turns[index].phase = .unanswered(.noAnswer)
                    }
                    return
                case .unknown:
                    continue
                }
            }
            // Closed with no `done`. A refusal or a halt already said how it ended.
            // The whole answer, if it came, is still the answer.
            guard !Task.isCancelled, halted == nil else { return }
            turns[index].phase = answer.map { .answered($0.text, proposal: $0.proposal) } ?? .unanswered(.interrupted)
        } catch {
            guard !Task.isCancelled else { return }
            if let refused = error as? AssistantAskError {
                if refused == .disabled || refused == .playersOnly { unavailable = refused }
                turns[index].phase = .unanswered(.refused(refused))
            } else if opened {
                // An answer that had arrived stays: only what came after it was lost.
                if let answer {
                    turns[index].phase = .answered(answer.text, proposal: answer.proposal)
                } else {
                    turns[index].phase = .unanswered(Self.isLostConnection(error) ? .lostMidAnswer : .interrupted)
                }
            } else {
                turns[index].phase = .unanswered(.offline)
            }
        }
    }

    /// The network went: the person left the app past iOS's grace, or the
    /// signal did. The generated client wraps the transport's error.
    public nonisolated static func isLostConnection(_ error: Error) -> Bool {
        let underlying = (error as? ClientError)?.underlyingError ?? error
        guard let error = underlying as? URLError else { return false }
        return [.networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .timedOut]
            .contains(error.code)
    }
}
