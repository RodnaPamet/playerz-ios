import PlayerzAPI
import SwiftUI

/// «Известия» (playerz-ios#15): the caller's notifications, newest first, as
/// the web's bell lists them. Opening the list marks every one read, as on the
/// web; the rows that were unread stay emphasised while it is open. A row
/// opens its screen when the app has one (`AppLink`).
struct NotificationsView: View {
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var items: [Components.Schemas.Notification] = []
    @State private var nextCursor: String?
    @State private var wasUnread: Set<String> = []
    @State private var phase: Phase = .loading
    @State private var destination: AppLink?

    enum Phase { case loading, loaded, failed }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "notifications.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.close"), action: close)
                    }
                }
                .navigationDestination(item: $destination) { link in
                    LinkedScreen(link: link, session: session)
                }
        }
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .failed:
            ContentUnavailableView {
                Text(String(localized: "notifications.error"))
            } actions: {
                Button(String(localized: "notifications.retry"), action: retry)
            }
        case .loaded where items.isEmpty:
            ContentUnavailableView(
                String(localized: "notifications.empty"),
                systemImage: "bell",
                description: Text(String(localized: "notifications.emptyBody"))
            )
        case .loaded:
            List(items, id: \.id) { item in
                NotificationRow(item: item, emphasised: wasUnread.contains(item.id), opens: link(item) != nil) {
                    open(item)
                }
                .onAppear {
                    if item.id == items.last?.id { Task { await loadMore() } }
                }
            }
            .refreshable { await load() }
        }
    }

    private func link(_ item: Components.Schemas.Notification) -> AppLink? {
        AppLink(href: item.href, refType: item.refType, refId: item.refId)
    }

    private func open(_ item: Components.Schemas.Notification) {
        guard let link = link(item) else { return }
        if session.isTab(link) {
            session.open(link)
            dismiss()
        } else {
            destination = link
        }
    }

    private func close() {
        dismiss()
    }

    private func retry() {
        phase = .loading
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client.listMyNotifications().ok.body.json.data
            items = page.items
            nextCursor = page.nextCursor
            wasUnread.formUnion(page.items.filter { !$0.read }.map(\.id))
            phase = .loaded
            if page.unreadCount > 0 { await markAllRead(client) }
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        if let page = try? await client.listMyNotifications(query: .init(cursor: cursor)).ok.body.json.data {
            items += page.items
            nextCursor = page.nextCursor
            wasUnread.formUnion(page.items.filter { !$0.read }.map(\.id))
        }
    }

    /// As the web: opening the list reads everything in it. A failure leaves
    /// the count as it was, to be read again in a minute.
    private func markAllRead(_ client: Client) async {
        let response = try? await client.markMyNotificationsRead(body: .json(.case2(.init(all: true))))
        if case let .ok(ok)? = response, let marked = try? ok.body.json.data {
            session.notificationsUnread = marked.unreadCount
        }
    }
}
