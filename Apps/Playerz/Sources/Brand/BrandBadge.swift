import SwiftUI

enum BrandBadgeStyle {
    /// Accent fill: on a card or a dark surface.
    case accent
    /// Ink fill with accent text: on the light page, as in an empty state.
    case ink
    /// Quiet: the chip grey with ordinary text, for a state that is over
    /// («Отменена», «Приключила») beside the accent of one that is live.
    case neutral
}

/// A small capsule word: «Скоро», «Ново».
struct BrandBadge: View {
    let text: String
    var style: BrandBadgeStyle = .accent

    init(_ text: String, style: BrandBadgeStyle = .accent) {
        self.text = text
        self.style = style
    }

    /// «Скоро» / "Coming soon".
    static func comingSoon(style: BrandBadgeStyle = .accent) -> BrandBadge {
        BrandBadge(String(localized: "brand.comingSoon"), style: style)
    }

    var body: some View {
        switch style {
        case .accent:
            label.foregroundStyle(Theme.Palette.onAccent)
                .background(Theme.Palette.accentFill, in: .capsule)
        case .ink:
            // Ink in both modes; the accent on it is its dark value (7:1).
            label.foregroundStyle(Theme.Palette.accentFill)
                .background(Theme.Palette.headerInk, in: .capsule)
                .overlay(Capsule().stroke(.white.opacity(0.16)))
                .environment(\.colorScheme, .dark)
        case .neutral:
            label.foregroundStyle(Color.primary)
                .background(Theme.Palette.chipIdle, in: .capsule)
        }
    }

    private var label: some View {
        Text(text)
            .font(Theme.Typography.badge)
            .textCase(.uppercase)
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 3)
    }
}

#Preview {
    VStack {
        BrandBadge.comingSoon()
        BrandBadge.comingSoon(style: .ink)
    }
    .padding()
}
