import PlayerzAPI
import SwiftUI

/// One notification as a card: an icon for what it is about, its title and
/// text, already in the reader's language as the server wrote them, how long
/// ago, and a dot while it is new.
struct NotificationRow: View {
    let item: Components.Schemas.Notification
    /// Unread when the list was opened.
    let emphasised: Bool
    /// The app has a screen for it.
    let opens: Bool
    let open: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var iconSide: CGFloat = 44

    var body: some View {
        // Only a row with a screen is a button: one the app cannot open yet
        // (a tournament, a coach's page) still reads in full, and is not dimmed.
        if opens {
            Button(action: open) { card }
                .buttonStyle(.brandCard)
                .accessibilityValue(emphasised ? String(localized: "notifications.new") : "")
        } else {
            card
                .accessibilityElement(children: .combine)
                .accessibilityValue(emphasised ? String(localized: "notifications.new") : "")
        }
    }

    private var card: some View {
        BrandContentCard {
            // At the accessibility sizes the icon sits above the words, which
            // then have the card's whole width.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.m))
            layout {
                icon
                words
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) { marks }
            .contentShape(.rect)
        }
    }

    private var icon: some View {
        Image(systemName: NotificationCategory(item).systemImage)
            .font(.headline)
            .foregroundStyle(Theme.Palette.accentText)
            .frame(width: min(iconSide, 64), height: min(iconSide, 64))
            .background(Theme.Palette.chipIdle, in: .rect(cornerRadius: Theme.Radius.tile))
            .accessibilityHidden(true)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // New is said twice over: the dot, and the heavier title.
            Text(item.title)
                .font(emphasised ? Theme.Typography.rowTitle : .body)
                // Clear of the dot and the chevron in the corner.
                .padding(.trailing, typeSize.isAccessibilitySize ? 0 : Theme.Spacing.xl)
            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(item.createdAt, format: .relative(presentation: .named))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .multilineTextAlignment(.leading)
    }

    private var marks: some View {
        HStack(spacing: Theme.Spacing.s) {
            if emphasised {
                Circle()
                    .fill(Theme.Palette.accentFill)
                    .frame(width: 10, height: 10)
            }
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityHidden(true)
    }
}
