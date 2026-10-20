import PlayerzAPI
import SwiftUI

/// One person on the booking, and «Пиши» to a registered other player while
/// the server has messaging on (#16).
struct BookingPlayerRow: View {
    let player: Components.Schemas.BookingPlayer
    let name: String
    let messaging: Bool
    let write: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                if player.isBooker {
                    Text(String(localized: "bookingPlayers.booker"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if messaging, !player.isYou, player.registered, !player.deleted {
                Button(String(localized: "messages.write"), action: write)
                    .buttonStyle(.bordered)
                    .accessibilityLabel(String(localized: "a11y.writeTo \(name)"))
            }
        }
    }
}
