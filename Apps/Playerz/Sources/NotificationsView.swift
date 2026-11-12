import PlayerzAPI
import SwiftUI

/// «Известия» (playerz-ios#15): the caller's notifications, newest first, as
/// the web's bell lists them, as cards under chips for what they are about. Opening the list marks every one read, as on the
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
    /// The chip: one kind of notification, or nil for «Всички».
    @State private var filter: NotificationCategory?
    @State private var filling = false

    enum Phase { case loading, loaded, failed }

    var body: some View {
        NavigationStack {
            content
                .brandPage()
                // Hidden with the system bar, but still what a pushed screen's back button says.
                .navigationTitle(String(localized: "notifications.title"))
                .brandChipBar {
                    BrandChipRow {
                        BrandChip(String(localized: "notifications.filter.all"), isSelected: filter == nil) {
                            filter = nil
                        }
                        ForEach(NotificationCategory.chips(session.modules), id: \.self) { category in
                            BrandChip(category.label, isSelected: filter == category) { filter = category }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "notifications.filters"))
                }
                // A first screen over the tabs: back closes it (and VoiceOver's scrub).
                .brandHeader(.back(String(localized: "notifications.title"), action: close))
                .navigationDestination(item: $destination) { link in
                    LinkedScreen(link: link, session: session)
                }
        }
        .task { await load() }
        // The server pages by time, not by kind: read on until the chosen
        // kind has a screenful, or there is nothing older.
        .task(id: filter) { await fill() }
    }

    /// What the chosen chip leaves of the pages read so far.
    private var shown: [Components.Schemas.Notification] {
        guard let filter else { return items }
        return items.filter { NotificationCategory(kind: $0.kind) == filter }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "notifications.error")) {
                Button(String(localized: "notifications.retry"), action: retry)
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: "bell",
                title: String(localized: "notifications.empty"),
                message: String(localized: "notifications.emptyBody")
            )
        case .loaded where shown.isEmpty:
            if nextCursor != nil || filling {
                ProgressView(String(localized: "common.loading"))
            } else {
                BrandEmptyState(
                    systemImage: filter?.systemImage ?? "bell",
                    title: String(localized: "notifications.emptyFiltered"),
                    message: String(localized: "notifications.emptyFilteredBody")
                )
            }
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    ForEach(shown, id: \.id) { item in
                        NotificationRow(item: item, emphasised: wasUnread.contains(item.id), opens: link(item) != nil) {
                            open(item)
                        }
                        .onAppear {
                            if item.id == shown.last?.id { Task { await loadMore() } }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
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

    /// Older pages, while the chosen kind shows less than a screenful: the
    /// list would otherwise look empty, or end early, with more on the server.
    private func fill() async {
        guard filter != nil else { return }
        filling = true
        defer { filling = false }
        while !Task.isCancelled, phase == .loaded, shown.count < 8, nextCursor != nil {
            await loadMore()
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
