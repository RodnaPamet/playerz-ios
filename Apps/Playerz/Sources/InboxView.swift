import PlayerzAPI
import SwiftUI

/// Съобщения (#484): the caller's conversations, and «Заявки» — first messages
/// from players they have not played with yet (#375).
struct InboxView: View {
    @Bindable var session: SessionModel
    /// The tab's badge: unread conversations and requests, from the inbox.
    @Binding var unread: Int

    @State private var tab: Operations.listMyConversations.Input.Query.tabPayload = .conversations
    @State private var items: [Components.Schemas.ConversationSummary] = []
    @State private var nextCursor: String?
    @State private var phase: Phase = .loading
    @State private var path: [String] = DebugLaunch.conversation.map { [$0] } ?? []
    @State private var searching = false

    enum Phase { case loading, loaded, failed }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(String(localized: "messages.title"))
                // Inline: with a segmented control inset below the bar, iOS 26 hid the large
                // title under the bar's material.
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top) {
                    Picker(String(localized: "messages.tabs"), selection: $tab) {
                        Text(String(localized: "messages.tab.conversations")).tag(Operations.listMyConversations.Input.Query.tabPayload.conversations)
                        Text(String(localized: "messages.tab.requests")).tag(Operations.listMyConversations.Input.Query.tabPayload.requests)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .background(.bar)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "messages.new"), systemImage: "square.and.pencil") {
                            searching = true
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) { NotificationBell(session: session) }
                }
                .navigationDestination(for: String.self) { id in
                    ConversationView(conversationId: id, session: session)
                }
                .sheet(isPresented: $searching) {
                    PlayerSearchView(session: session) { id in
                        searching = false
                        path.append(id)
                    }
                }
        }
        .task(id: tab) { await load() }
        // Back from a conversation: what was read there is read here too.
        .onChange(of: path) { _, now in
            if now.isEmpty { Task { await load() } }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            ContentUnavailableView {
                Text(String(localized: "messages.failed"))
            } actions: {
                Button(String(localized: "venues.retry")) { Task { await load() } }
            }
        case .loaded where items.isEmpty:
            ContentUnavailableView(
                tab == .conversations
                    ? String(localized: "messages.empty")
                    : String(localized: "messages.emptyRequests"),
                systemImage: "bubble.left.and.bubble.right",
                description: Text(tab == .conversations
                    ? String(localized: "messages.emptyHint")
                    : String(localized: "messages.emptyRequestsHint"))
            )
        case .loaded:
            List {
                ForEach(items, id: \.id) { item in
                    NavigationLink(value: item.id) { ConversationRow(item: item) }
                        .onAppear {
                            if item.id == items.last?.id { Task { await loadMore() } }
                        }
                }
            }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client
                .listMyConversations(.init(query: .init(tab: tab)))
                .ok.body.json.data
            items = page.items
            nextCursor = page.nextCursor
            phase = .loaded
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
        if let counts = try? await client.getMyUnreadConversations().ok.body.json.data {
            unread = counts.conversations + counts.requests
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        if let page = try? await client
            .listMyConversations(.init(query: .init(tab: tab, cursor: cursor)))
            .ok.body.json.data {
            let seen = Set(items.map(\.id))
            items += page.items.filter { !seen.contains($0.id) }
            nextCursor = page.nextCursor
        }
    }
}

/// One conversation: who, the start of the last message, and what is unread.
private struct ConversationRow: View {
    let item: Components.Schemas.ConversationSummary

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ConversationText.title(item.counterpart))
                    .font(item.unreadCount > 0 ? .headline : .body)
                Text(ConversationText.preview(item.lastMessage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.lastMessageAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if item.unreadCount > 0 {
                    Text("\(item.unreadCount)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .background(.tint, in: .capsule)
                        .foregroundStyle(.white)
                        .accessibilityLabel(String(localized: "messages.unread \(item.unreadCount)"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
