import Foundation
import Observation

/// What the assistant keeps about the person (`/me/assistant-memory`) and
/// what they said to it (`/me/assistant-conversations`): read live and never
/// cached on disk, as personal as messaging.
public enum AssistantMemory {
    /// One remembered point, in the person's own language.
    public struct Point: Identifiable, Equatable, Sendable {
        public let id: String
        public let text: String
        /// When the person said it, or last corrected it.
        public let rememberedAt: Date
        /// The person corrected it: the assistant never changes it.
        public let editedByPerson: Bool

        public init(id: String, text: String, rememberedAt: Date, editedByPerson: Bool = false) {
            self.id = id
            self.text = text
            self.rememberedAt = rememberedAt
            self.editedByPerson = editedByPerson
        }

        init(_ wire: Components.Schemas.RememberedPoint) {
            self.init(id: wire.id, text: wire.text, rememberedAt: wire.rememberedAt, editedByPerson: wire.editedByPerson)
        }

        /// The server saves at most this many characters of an edit.
        public static let maxLength = 280
    }

    /// One past exchange, recognisable by the person's own first question.
    public struct Conversation: Identifiable, Equatable, Sendable {
        public let id: String
        /// The first question; nil when the server has none to show.
        public let opening: String?
        public let lastTurnAt: Date
        /// The turns it holds, the answers included.
        public let turns: Int

        public init(id: String, opening: String?, lastTurnAt: Date, turns: Int) {
            self.id = id
            self.opening = opening
            self.lastTurnAt = lastTurnAt
            self.turns = turns
        }

        init(_ wire: Components.Schemas.AssistantConversationSummary) {
            let opening = wire.opening?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.init(
                id: wire.id, opening: opening?.isEmpty == false ? opening : nil,
                lastTurnAt: wire.lastTurnAt, turns: wire.turns
            )
        }
    }

    /// One past exchange to read and continue: oldest turn first.
    public struct Transcript: Equatable, Sendable {
        public struct Item: Equatable, Sendable {
            public enum Role: String, Sendable { case user, assistant }
            public let role: Role
            public let text: String

            public init(role: Role, text: String) {
                self.role = role
                self.text = text
            }
        }

        public let id: String
        public let items: [Item]
        /// Longer than `items`: the OLDEST turns were left out.
        public let truncated: Bool

        public init(id: String, items: [Item], truncated: Bool) {
            self.id = id
            self.items = items
            self.truncated = truncated
        }

        init(_ wire: Components.Schemas.AssistantConversationDetail) {
            self.init(
                id: wire.id,
                items: wire.items.map { Item(role: $0.role == .user ? .user : .assistant, text: $0.text) },
                truncated: wire.truncated
            )
        }
    }
}

/// A list the person can make the assistant forget: the remembered points and
/// the past conversations, one row swiped away with a few seconds of
/// «Отмени», or all of it at once.
///
/// One store for both, not two copies of it: the window, a second swipe and
/// leaving the screen must send a row exactly once between them, and that is
/// the part worth proving once (`AssistantMemoryTests`).
///
/// ── Hidden at once, forgotten after the window ──
///
/// The row leaves the list and the bar under it offers «Отмени». Only once the
/// window closes is it forgotten on the server, where forgetting is for good.
/// Leaving the screen sends it at once (`flush`).
@MainActor
@Observable
public final class ForgettableList<Item: Identifiable & Equatable & Sendable> where Item.ID == String {
    public enum State: Equatable {
        case loading
        case loaded([Item])
        case failed(AssistantMemoryError)
    }

    public private(set) var state: State = .loading
    /// The row waiting out its window, for the bar's «Отмени».
    public private(set) var undoable: Item?
    public private(set) var hidden: Set<String> = []
    /// The last refusal, for the screen to say; cleared by the screen.
    public var failure: AssistantMemoryError?

    /// Swiped and not yet sent. Taken out as a send starts, so the window,
    /// a second swipe and leaving the screen send a row once between them.
    @ObservationIgnored private var pending: Set<String> = []
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private let window: Duration
    @ObservationIgnored public let api: API

    /// The server, swapped in tests. `edit` only where a row can be
    /// corrected: a remembered point can, a conversation cannot.
    public struct API {
        public var list: @MainActor () async throws -> [Item]
        public var forget: @MainActor (String) async throws -> Void
        public var forgetAll: @MainActor () async throws -> Void
        public var edit: (@MainActor (String, String) async throws -> Item)?

        public init(
            list: @escaping @MainActor () async throws -> [Item],
            forget: @escaping @MainActor (String) async throws -> Void,
            forgetAll: @escaping @MainActor () async throws -> Void,
            edit: (@MainActor (String, String) async throws -> Item)? = nil
        ) {
            self.list = list
            self.forget = forget
            self.forgetAll = forgetAll
            self.edit = edit
        }
    }

    /// Five seconds, as every «Отмени» in the app; longer under VoiceOver or
    /// Switch Control (`assistedWindow`), passed per swipe.
    public static var defaultWindow: Duration { .seconds(5) }
    public static var assistedWindow: Duration { .seconds(12) }

    public init(window: Duration = .seconds(5), api: API) {
        self.window = window
        self.api = api
    }

    public var value: [Item]? {
        if case let .loaded(items) = state { return items }
        return nil
    }

    /// What the list shows: everything not waiting to be forgotten.
    public var items: [Item] {
        (value ?? []).filter { !hidden.contains($0.id) }
    }

    /// A failed reload keeps what was shown.
    public func load() async {
        if value == nil { state = .loading }
        do {
            state = .loaded(try await api.list())
        } catch {
            if value == nil { state = .failed(Self.problem(error)) }
        }
    }

    /// Swiped away: hidden now, forgotten when the window closes. A second
    /// one sends the first at once, as the bar names only one.
    public func forget(_ item: Item, window override: Duration? = nil) {
        if let earlier = undoable { commitNow(earlier) }
        hidden.insert(item.id)
        pending.insert(item.id)
        undoable = item
        let window = override ?? window
        timer = Task { [weak self] in
            try? await Task.sleep(for: window)
            guard !Task.isCancelled else { return }
            await self?.commit(item)
        }
    }

    public func undo() {
        guard let item = undoable else { return }
        timer?.cancel()
        timer = nil
        pending.remove(item.id)
        hidden.remove(item.id)
        undoable = nil
    }

    /// Leaving the screen inside the window forgets the row then: the store
    /// goes with the screen, and its timer with it.
    public func flush() {
        if let item = undoable { commitNow(item) }
    }

    private func commitNow(_ item: Item) {
        timer?.cancel()
        timer = nil
        Task { await commit(item) }
    }

    public func commit(_ item: Item) async {
        guard pending.remove(item.id) != nil else { return }
        if undoable?.id == item.id { undoable = nil }
        do {
            try await api.forget(item.id)
            replace(item.id) { _ in nil }
            hidden.remove(item.id)
        } catch {
            hidden.remove(item.id)
            failure = Self.problem(error)
        }
    }

    /// «Изтрий всичко», asked first by the screen: nothing comes back.
    public func forgetAll() async {
        timer?.cancel()
        timer = nil
        undoable = nil
        pending = []
        do {
            try await api.forgetAll()
            state = .loaded([])
            hidden = []
        } catch {
            // Nothing was forgotten, the swiped one included, whose send
            // this cancelled: back in the list, as it is on the server.
            hidden = []
            failure = Self.problem(error)
        }
    }

    /// One row changed (`change` answers its new value) or gone (nil).
    public func replace(_ id: String, with change: (Item) -> Item?) {
        guard case let .loaded(items) = state else { return }
        state = .loaded(items.compactMap { $0.id == id ? change($0) : $0 })
    }

    static func problem(_ error: Error) -> AssistantMemoryError {
        (error as? AssistantMemoryError) ?? .failed
    }
}

/// «Запомнено»: the points, which a person can also correct.
public typealias AssistantMemoryStore = ForgettableList<AssistantMemory.Point>

/// «Минали разговори»: forgotten, never corrected.
public typealias PastConversationsStore = ForgettableList<AssistantMemory.Conversation>

extension ForgettableList where Item == AssistantMemory.Point {
    /// The person's own wording. Nil on success, the refusal otherwise. A
    /// point forgotten meanwhile (from the web, say) leaves the list.
    public func edit(_ point: Item, to text: String) async -> AssistantMemoryError? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let send = api.edit else { return nil }
        do {
            let saved = try await send(point.id, String(trimmed.prefix(AssistantMemory.Point.maxLength)))
            replace(point.id) { _ in saved }
            return nil
        } catch {
            let problem = Self.problem(error)
            if problem == .notFound { replace(point.id) { _ in nil } }
            return problem
        }
    }
}
