import Foundation
import Observation
import PlayerzAPI

/// One conversation (#484): its messages, read again every five seconds while
/// it is open, and everything the caller can do in it.
@MainActor
@Observable
final class ConversationModel {
    let conversationId: String

    private(set) var conversation: Components.Schemas.Conversation?
    /// The newest page, read again on every refresh, and the older pages the
    /// caller asked for, kept as they were.
    private var latest: [Components.Schemas.Message] = []
    private var older: [Components.Schemas.Message] = []
    private(set) var olderCursor: String?

    /// Every message loaded so far, oldest first.
    var messages: [Components.Schemas.Message] {
        let newest = Set(latest.map(\.id))
        return older.filter { !newest.contains($0.id) } + latest
    }
    private(set) var failed = false
    private(set) var sending = false
    private(set) var problem: String?

    /// One key per message being sent: a retry after a lost response answers
    /// the first send (`replayed`) instead of sending it twice. A different
    /// text is a different message, with a fresh key.
    private var pendingKey: (text: String, key: String)?

    /// The server's limit, after it removes markup (#375).
    let maxLength = 4000

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            failed = conversation == nil
            return
        }
        do {
            let fresh = try await client
                .getMyConversation(path: .init(id: conversationId))
                .ok.body.json.data
            conversation = fresh
            latest = fresh.messages
            // Until the caller pages back, "older" starts where this page does.
            if older.isEmpty { olderCursor = fresh.olderCursor }
            failed = false
            if fresh.unreadCount > 0 {
                _ = try? await client.markMyConversationRead(path: .init(id: conversationId))
            }
        } catch {
            failed = conversation == nil
        }
    }

    /// While the screen is open: read again every five seconds (#484).
    func poll(_ session: SessionModel) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            await load(session)
        }
    }

    func loadOlder(_ session: SessionModel) async {
        guard let cursor = olderCursor, let client = await session.client() else { return }
        if let page = try? await client
            .getMyConversation(path: .init(id: conversationId), query: .init(before: cursor))
            .ok.body.json.data {
            let seen = Set(messages.map(\.id))
            older = page.messages.filter { !seen.contains($0.id) } + older
            olderCursor = page.olderCursor
        }
    }

    /// Sends `text`; true when it went, so the composer can clear.
    func send(_ text: String, _ session: SessionModel) async -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let client = await session.client() else { return false }
        if pendingKey?.text != body { pendingKey = (body, UUID().uuidString) }
        sending = true
        problem = nil
        defer { sending = false }
        do {
            let response = try await client.sendMyMessage(
                path: .init(id: conversationId),
                headers: .init(Idempotency_hyphen_Key: pendingKey!.key),
                body: .json(.init(body: body))
            )
            switch response {
            case .ok, .created:
                pendingKey = nil
                await load(session)
                return true
            default:
                problem = ConversationText.error(apiErrorCode(response))
                return false
            }
        } catch {
            problem = ConversationText.error(nil)
            return false
        }
    }

    func answer(accept: Bool, _ session: SessionModel) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            if accept {
                let response = try await client.acceptMyConversation(path: .init(id: conversationId))
                if case .ok = response {} else { problem = ConversationText.error(apiErrorCode(response)) }
            } else {
                let response = try await client.declineMyConversation(path: .init(id: conversationId))
                if case .ok = response {} else { problem = ConversationText.error(apiErrorCode(response)) }
            }
        } catch {
            problem = ConversationText.error(nil)
        }
        await load(session)
    }

    func setBlocked(_ block: Bool, _ session: SessionModel) async {
        guard let client = await session.client() else { return }
        problem = nil
        do {
            if block {
                let response = try await client.blockMyConversation(path: .init(id: conversationId))
                if case .ok = response {} else { problem = String(localized: "messages.blockFailed") }
            } else {
                let response = try await client.unblockMyConversation(path: .init(id: conversationId))
                if case .ok = response {} else { problem = String(localized: "messages.blockFailed") }
            }
        } catch {
            problem = String(localized: "messages.blockFailed")
        }
        await load(session)
    }

    func retract(_ messageId: String, _ session: SessionModel) async {
        guard let client = await session.client() else { return }
        let response = try? await client.retractMyMessage(path: .init(id: messageId))
        if response.map({ if case .ok = $0 { true } else { false } }) != true {
            problem = ConversationText.error(response.flatMap { apiErrorCode($0) })
        }
        await load(session)
    }

    enum Reported: Hashable, Identifiable {
        case message(String), conversation
        var id: Self { self }
    }

    /// A report to playerz's moderators; true when it was received.
    func report(
        _ what: Reported,
        reason: Components.Schemas.ReportRequest.reasonPayload,
        details: String,
        _ session: SessionModel
    ) async -> Bool {
        guard let client = await session.client() else { return false }
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Components.Schemas.ReportRequest(reason: reason, details: trimmed.isEmpty ? nil : trimmed)
        do {
            switch what {
            case .message(let id):
                let response = try await client.reportMyMessage(path: .init(id: id), body: .json(body))
                if case .created = response { return true }
            case .conversation:
                let response = try await client.reportMyConversation(
                    path: .init(id: conversationId), body: .json(body)
                )
                if case .created = response { return true }
            }
        } catch {}
        return false
    }
}
