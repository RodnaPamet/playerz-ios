import PlayerzAPI
import SwiftUI

/// Съобщения (#484): the caller's conversations, and «Заявки» — first messages
/// from players they have not played with yet (#375). Laid over the tabs
/// from a header's messages button (PlayerShell).
struct InboxView: View {
    @Bindable var session: SessionModel
    /// The header button's dot: unread conversations and requests, from the inbox.
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
                .brandPage()
                // Hidden with the system bar, but still what a conversation's back button says.
                .navigationTitle(String(localized: "messages.title"))
                .brandChipBar {
                    BrandChipRow {
                        BrandChip(String(localized: "messages.tab.conversations"), isSelected: tab == .conversations) {
                            tab = .conversations
                        }
                        BrandChip(String(localized: "messages.tab.requests"), isSelected: tab == .requests) {
                            tab = .requests
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "messages.tabs"))
                }
                // Over the tabs: back closes it (and VoiceOver's scrub, through the header).
                .brandHeader(.back(String(localized: "messages.title"), action: close)) {
                    BrandHeaderButton(systemImage: "square.and.pencil", label: String(localized: "messages.new")) {
                        searching = true
                    }
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
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "messages.failed")) {
                Button(String(localized: "venues.retry")) { Task { await load() } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: "bubble.left.and.bubble.right",
                title: tab == .conversations
                    ? String(localized: "messages.empty")
                    : String(localized: "messages.emptyRequests"),
                message: tab == .conversations
                    ? String(localized: "messages.emptyHint")
                    : String(localized: "messages.emptyRequestsHint")
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(items, id: \.id) { item in
                        NavigationLink(value: item.id) {
                            BrandContentCard { ConversationRow(item: item, avatarURL: avatarURL(item)) }
                        }
                        .buttonStyle(.brandCard)
                        .onAppear {
                            if item.id == items.last?.id { Task { await loadMore() } }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await load() }
        }
    }

    /// A player's picture, when the server has one; a club and a game have none.
    private func avatarURL(_ item: Components.Schemas.ConversationSummary) -> URL? {
        if case let .case1(player) = item.counterpart, !player.deleted {
            return session.mediaURL(player.avatarUrl)
        }
        return nil
    }

    private func close() {
        session.messagesOpen = false
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

/// One conversation: who, when, the start of the last message, and what is unread.
private struct ConversationRow: View {
    let item: Components.Schemas.ConversationSummary
    let avatarURL: URL?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let name = ConversationText.title(item.counterpart)
        // At the accessibility sizes the picture goes above the words, so the
        // name has the card's whole width and is not cut short.
        let large = typeSize.isAccessibilitySize
        let layout = large
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.m))
        layout {
            avatar(name)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // The name is who this is: it is never the one cut short. On
                // one line with the time while both fit whole; otherwise the
                // name takes the line and the time goes under it.
                BrandTitleLine {
                    nameText(name).lineLimit(large ? nil : 2)
                    time
                }
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Text(ConversationText.preview(item.lastMessage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(large ? 3 : 2)
                    Spacer(minLength: 0)
                    if item.unreadCount > 0 {
                        Text("\(item.unreadCount)")
                            .font(Theme.Typography.badge)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Palette.onAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .frame(minWidth: 20)
                            .background(Theme.Palette.accentFill, in: .capsule)
                            .accessibilityLabel(String(localized: "messages.unread \(item.unreadCount)"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !large { chevron }
        }
        .overlay(alignment: .topTrailing) {
            if large { chevron }
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func nameText(_ name: String) -> some View {
        // Unread is said by the count and by the heavier name, not by colour.
        Text(name).font(item.unreadCount > 0 ? Theme.Typography.rowTitle : .body)
    }

    private var time: some View {
        Text(item.lastMessageAt, format: .relative(presentation: .named))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private func avatar(_ name: String) -> some View {
        switch item.counterpart {
        case .case1: BrandAvatar(name: name, url: avatarURL)
        case .case2: BrandAvatar(name: name, systemImage: "building.2")
        case .case3: BrandAvatar(name: name, systemImage: "person.3")
        }
    }
}
