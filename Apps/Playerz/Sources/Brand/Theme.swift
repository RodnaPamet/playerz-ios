import SwiftUI
import UIKit

/// The restyle's tokens: every colour, radius, gap, shadow and text style the
/// Brand* components use. One place, so the accent is a one-line change and
/// no screen carries a hex value of its own.
enum Theme {
    /// Colours, each with a light and a dark value unless it sits on a surface
    /// that is dark in both (the header band, a dark sheet).
    enum Palette {
        /// The page behind cards and lists.
        static var page: Color { Color(light: 0xF4F4F7, dark: 0x0B0B12) }
        /// A card, a list row, the floating bar.
        static var card: Color { Color(light: 0xFFFFFF, dark: 0x181822) }

        /// The header band, dark in both modes; `headerGlow` is the purple it fades to.
        static var headerInk: Color { Color(hex: 0x0B0B12) }
        static var headerGlow: Color { Color(hex: 0x2B1A66) }
        static var onHeader: Color { .white }

        /// THE accent: the web's purple. White text on it is 5.9:1; the dark
        /// value is lighter, so its text is the ink (7.3:1), not white (3.1:1).
        static var accentFill: Color { Color(light: 0x6D3FE8, dark: 0xA48CFF) }
        static var onAccent: Color { Color(light: 0xFFFFFF, dark: 0x0B0B12) }
        /// Accent-coloured text and icons on `page` or `card`; also the app's tint.
        static var accentText: Color { Color(light: 0x6D3FE8, dark: 0xB3A0FF) }

        static var chipIdle: Color { Color(light: 0xE8E8EE, dark: 0x262633) }
        static var chipSelected: Color { accentFill }

        /// The strongest contrast with the page: the bar's round centre button.
        static var inverse: Color { Color(light: 0x0B0B12, dark: 0xF4F4F7) }
        static var onInverse: Color { Color(light: 0xFFFFFF, dark: 0x0B0B12) }

        /// A dark bottom sheet and a row in it, dark in both modes.
        static var sheetSurface: Color { Color(hex: 0x14141D) }
        static var sheetRow: Color { Color(hex: 0x20202C) }

        static var hairline: Color { Color(light: 0xE2E2E8, dark: 0x2C2C3A) }
        /// A count or an unread dot; white on it is 4.8:1.
        static var badge: Color { Color(hex: 0xD92D3A) }
        static var onBadge: Color { .white }
    }

    enum Radius {
        static let card: CGFloat = 24
        static let sheet: CGFloat = 28
        static let row: CGFloat = 20
        /// An icon square, a logo square.
        static let tile: CGFloat = 14
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// The smallest side of anything tappable.
    static let minTarget: CGFloat = 44

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat

        static var card: Shadow { Shadow(color: .black.opacity(0.08), radius: 12, y: 4) }
        static var floating: Shadow { Shadow(color: .black.opacity(0.18), radius: 18, y: 8) }
    }

    /// Text styles, all on the system's Dynamic Type styles: none has a fixed size.
    enum Typography {
        static var wordmark: Font { .system(.title, design: .rounded, weight: .heavy) }
        static var headerTitle: Font { .title3.weight(.bold) }
        static var sectionTitle: Font { .title3.weight(.bold) }
        static var cardTitle: Font { .title3.weight(.bold) }
        static var cardSubtitle: Font { .subheadline }
        static var rowTitle: Font { .headline }
        static var chip: Font { .subheadline.weight(.semibold) }
        static var button: Font { .headline }
        static var tabLabel: Font { .caption2.weight(.semibold) }
        static var badge: Font { .caption2.weight(.heavy) }
    }
}

extension Color {
    /// A colour with a light and a dark value, each 0xRRGGBB.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// The same colour in both modes, 0xRRGGBB.
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    func themeShadow(_ shadow: Theme.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }

    /// The page colour behind a whole screen: a List or Form loses its own
    /// background, and a spinner or an empty state is stretched to fill.
    func brandPage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.page.ignoresSafeArea())
    }
}

#Preview("Palette") {
    let swatches: [(String, Color)] = [
        ("page", Theme.Palette.page), ("card", Theme.Palette.card),
        ("headerInk", Theme.Palette.headerInk), ("headerGlow", Theme.Palette.headerGlow),
        ("accentFill", Theme.Palette.accentFill), ("accentText", Theme.Palette.accentText),
        ("chipIdle", Theme.Palette.chipIdle), ("inverse", Theme.Palette.inverse),
        ("sheetSurface", Theme.Palette.sheetSurface), ("sheetRow", Theme.Palette.sheetRow),
        ("hairline", Theme.Palette.hairline), ("badge", Theme.Palette.badge),
    ]
    return List(swatches, id: \.0) { name, color in
        HStack {
            RoundedRectangle(cornerRadius: 8).fill(color).frame(width: 44, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Palette.hairline))
            Text(verbatim: name)
        }
    }
}
