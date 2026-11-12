import PlayerzAPI
import SwiftUI

/// The bell (playerz-ios#15), as in the web's header: «Известия» with the
/// unread count, a round button on the header band. RootView presents the one
/// list and reads the count every minute.
struct NotificationBell: View {
    @Bindable var session: SessionModel

    var body: some View {
        BrandHeaderButton(
            systemImage: "bell",
            label: label,
            badge: session.notificationsUnread > 0 ? .count(session.notificationsUnread) : .none,
            action: show
        )
    }

    private var label: String {
        session.notificationsUnread > 0
            ? String(localized: "notifications.unread \(session.notificationsUnread)")
            : String(localized: "notifications.title")
    }

    private func show() {
        session.notificationsOpen = true
    }
}

/// «Съобщения» beside the bell, with a dot while something is unread: the
/// inbox left the tab bar for the header, where the web has it.
struct MessagesButton: View {
    @Bindable var session: SessionModel

    var body: some View {
        BrandHeaderButton(
            systemImage: "bubble.left",
            label: label,
            badge: session.messagesUnread > 0 ? .dot : .none,
            action: show
        )
    }

    private var label: String {
        let title = String(localized: "messages.title")
        guard session.messagesUnread > 0 else { return title }
        return title + ", " + String(localized: "messages.unread \(session.messagesUnread)")
    }

    private func show() {
        session.messagesOpen = true
    }
}

/// What every tab's header ends with: messages, while that module is on
/// (#16), and the bell.
struct BrandHeaderActions: View {
    @Bindable var session: SessionModel

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if session.modules.messaging {
                MessagesButton(session: session)
            }
            NotificationBell(session: session)
        }
    }
}
