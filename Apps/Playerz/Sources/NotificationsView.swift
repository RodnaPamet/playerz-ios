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
    /// The chip: one group of notifications, or nil for «Всички». The server
    /// filters by it (projectZ#677), so a chosen group pages on its own.
    @State private var filter: NotificationCategory?
    /// Unread per group as the list opened, before opening marked them read:
    /// what the chips show.
    @State private var unreadAtOpen: [NotificationCategory: Int] = [:]

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
                            BrandChip(chipLabel(category), isSelected: filter == category) { filter = category }
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
        // The first read, and a new one for each chip.
        .task(id: filter) { await load() }
    }

    private var shown: [Components.Schemas.Notification] { items }

    private func chipLabel(_ category: NotificationCategory) -> String {
        let unread = unreadAtOpen[category] ?? 0
        return unread > 0 ? "\(category.label) · \(unread)" : category.label
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
        case .loaded where items.isEmpty && filter == nil:
            BrandEmptyState(
                systemImage: "bell",
                title: String(localized: "notifications.empty"),
                message: String(localized: "notifications.emptyBody")
            )
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: filter?.systemImage ?? "bell",
                title: String(localized: "notifications.emptyFiltered"),
                message: String(localized: "notifications.emptyFilteredBody")
            )
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
            let asked = filter
            let page = try await client
                .listMyNotifications(query: .init(category: asked.flatMap(Self.serverCategory)))
                .ok.body.json.data
            guard asked == filter else { return }
            items = page.items
            nextCursor = page.nextCursor
            wasUnread.formUnion(page.items.filter { !$0.read }.map(\.id))
            if unreadAtOpen.isEmpty {
                let u = page.unreadByCategory
                unreadAtOpen = [
                    .bookings: u.bookings, .games: u.games, .messages: u.messages,
                    .lessons: u.lessons, .tournaments: u.tournaments, .other: u.other,
                ]
            }
            phase = .loaded
            if page.unreadCount > 0 { await markAllRead(client) }
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        let query = Operations.listMyNotifications.Input.Query(
            cursor: cursor, category: filter.flatMap(Self.serverCategory)
        )
        if let page = try? await client.listMyNotifications(query: query).ok.body.json.data {
            items += page.items
            nextCursor = page.nextCursor
            wasUnread.formUnion(page.items.filter { !$0.read }.map(\.id))
        }
    }

    private static func serverCategory(_ category: NotificationCategory) -> Components.Schemas.NotificationCategory? {
        Components.Schemas.NotificationCategory(rawValue: category.rawValue)
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
