import PlayerzAPI
import SwiftUI

/// The bell (playerz-ios#15), as in the web's header: «Известия» with the
/// unread count. Placed in each tab's bar; RootView presents the one list
/// and reads the count every minute.
struct NotificationBell: View {
    @Bindable var session: SessionModel

    var body: some View {
        Button(String(localized: "notifications.title"), systemImage: session.notificationsUnread > 0 ? "bell.badge" : "bell", action: show)
            .accessibilityLabel(label)
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
