import PlayerzAPI
import SwiftUI

/// One notification: its title and text, already in the reader's language
/// as the server wrote them, and how long ago.
struct NotificationRow: View {
    let item: Components.Schemas.Notification
    /// Unread when the list was opened.
    let emphasised: Bool
    /// The app has a screen for it.
    let opens: Bool
    let open: () -> Void

    var body: some View {
        // Only a row with a screen is a button: one the app cannot open yet
        // (a tournament, a coach's page) still reads in full, and is not dimmed.
        if opens {
            Button(action: open) { content }
                .buttonStyle(.plain)
                .accessibilityValue(emphasised ? String(localized: "notifications.new") : "")
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityValue(emphasised ? String(localized: "notifications.new") : "")
        }
    }

    private var content: some View {
        HStack(alignment: .firstTextBaseline) {
            Circle()
                .fill(emphasised ? Color.accentColor : .clear)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(emphasised ? .headline : .body)
                Text(item.body).font(.subheadline).foregroundStyle(.secondary)
                Text(item.createdAt, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }
}
