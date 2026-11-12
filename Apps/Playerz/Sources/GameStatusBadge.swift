import PlayerzAPI
import SwiftUI

/// A small word on a game: a symbol and text, so nothing is told by colour
/// alone, and it wraps at the largest text sizes instead of cutting the word.
struct GameTag: View {
    let text: String
    let systemImage: String
    var filled = true

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(filled ? Theme.Palette.onAccent : Color.primary)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(filled ? Theme.Palette.accentFill : Theme.Palette.chipIdle, in: .rect(cornerRadius: Theme.Radius.tile))
    }
}

/// The caller's request in a game.
struct GameStatusBadge: View {
    let status: Components.Schemas.OpenGameRequestStatus

    var body: some View {
        GameTag(text: GameText.status(status), systemImage: symbol, filled: status == .ACCEPTED)
    }

    private var symbol: String {
        switch status {
        case .ACCEPTED: "checkmark.circle.fill"
        case .PENDING: "hourglass"
        default: "xmark.circle"
        }
    }
}
