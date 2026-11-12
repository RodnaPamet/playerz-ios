import PlayerzAPI
import SwiftUI

/// One person on the booking, and «Пиши» to a registered other player while
/// the server has messaging on (#16).
struct BookingPlayerRow: View {
    let player: Components.Schemas.BookingPlayer
    let name: String
    /// Their picture, when the server has one.
    var avatarURL: URL?
    let messaging: Bool
    let write: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At the accessibility sizes the name and «Пиши» cannot share a line
        // without cutting the name: the button goes under it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
        layout {
            HStack(spacing: Theme.Spacing.m) {
                // Decoration: at the accessibility sizes the name needs the width.
                if !typeSize.isAccessibilitySize {
                    BrandAvatar(
                        name: player.isYou || player.deleted ? nil : name,
                        url: player.deleted ? nil : avatarURL,
                        systemImage: player.isYou ? "checkmark" : player.deleted ? "person.fill" : nil
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Theme.Typography.rowTitle)
                    if player.isBooker {
                        Text(String(localized: "bookingPlayers.booker"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if messaging, !player.isYou, player.registered, !player.deleted {
                Button(String(localized: "messages.write"), action: write)
                    .buttonStyle(.brandSecondary(fullWidth: false))
                    .accessibilityLabel(String(localized: "a11y.writeTo \(name)"))
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
