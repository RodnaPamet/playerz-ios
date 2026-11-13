import SwiftUI
import UIKit

/// The restyle's tokens: every colour, radius, gap, shadow and text style the
/// Brand* components use. One place, so the accent is a one-line change and
/// no screen carries a hex value of its own.
enum Theme {
    /// Colours, each with a light and a dark value unless it sits on a surface
    /// that is dark in both (the header band, a dark sheet).
    enum Palette {
        /// The page behind cards and lists: warm paper in light mode, ink in
        /// dark (the design draft, owner 2026-11-13: "a bit of elegance").
        static var page: Color { Color(light: 0xF6F4F0, dark: 0x101016) }
        /// A card, a list row, the floating bar.
        static var card: Color { Color(light: 0xFFFFFF, dark: 0x1A1A24) }

        /// The draft's ink, the same in both modes: the scrim over a sport's photo.
        static var ink: Color { Color(hex: 0x101016) }
        /// Secondary text on ink or on a photo's scrim (8.6:1 on ink).
        static var muted: Color { Color(hex: 0xB1AEBD) }
        /// The edge of a photo card, dark in both modes.
        static var photoEdge: Color { Color(hex: 0x453A58) }

        /// The header band, dark in both modes; `headerGlow` is the muted
        /// violet it fades to.
        static var headerInk: Color { Color(hex: 0x101016) }
        static var headerGlow: Color { Color(hex: 0x2B2245) }
        static var onHeader: Color { .white }

        /// THE action colour: the web's purple in light mode; in dark mode a
        /// dark gold, "like the golden hour sun light" (owner 2026-11-13, on
        /// "purple, yellow and white for the dark theme"), and on every
        /// surface that is dark in both modes (the header band, dark sheets).
        /// White on the purple is 5.9:1; the deep purple ink on the gold is
        /// 8.0:1. The draft's lavender carries everything chosen
        /// (`accentText`, `selectedFill`).
        static var accentFill: Color { Color(light: 0x6D3FE8, dark: 0xDDA13F) }
        static var onAccent: Color { Color(light: 0xFFFFFF, dark: 0x1A0B3D) }
        /// Accent-coloured text and icons on `page` or `card`, and what is
        /// chosen; also the app's tint. The draft's lavender in dark mode
        /// (9.4:1 on ink, 8.4:1 on the card).
        static var accentText: Color { Color(light: 0x6D3FE8, dark: 0xBCAAFF) }
        /// A switch that is ON: its knob is white in both modes, so the dark
        /// value stays deep (white on it is 4.9:1), unlike `accentText`.
        static var controlOn: Color { Color(light: 0x6D3FE8, dark: 0x7A52F0) }

        static var chipIdle: Color { Color(light: 0xEFECF3, dark: 0x191923) }
        /// A chosen chip, day or tab: a quiet violet under `accentText`
        /// (the draft's selected chip), not a fill that shouts.
        static var selectedFill: Color { Color(light: 0xEEE8FF, dark: 0x272137) }
        static var selectedEdge: Color { Color(light: 0xB9A5F5, dark: 0x635589) }

        /// The strongest contrast with the page: the bar's round centre button.
        static var inverse: Color { Color(light: 0x0B0B12, dark: 0xF4F4F7) }
        static var onInverse: Color { Color(light: 0xFFFFFF, dark: 0x120A28) }

        /// A dark bottom sheet and a row in it, dark in both modes.
        static var sheetSurface: Color { Color(hex: 0x16161F) }
        static var sheetRow: Color { Color(hex: 0x1F1E2A) }

        static var hairline: Color { Color(light: 0xE4E0E8, dark: 0x2C2B38) }
        /// A count or an unread dot; white on it is 4.8:1.
        static var badge: Color { Color(hex: 0xD92D3A) }
        static var onBadge: Color { .white }
        /// Text of an action that takes something away («Откажи», «Изход») and
        /// of a failure, on `page` or `card`: 6.1:1 light, 7.4:1 dark.
        static var danger: Color { Color(light: 0xC4222E, dark: 0xFF7A85) }
        /// Text of an outcome that went through («Запазено»), on `page` or
        /// `card`: 5.6:1 light; the draft's soft green in dark, 11:1.
        static var success: Color { Color(light: 0x1E7A3C, dark: 0xB5E7BD) }
    }

    enum Radius {
        static let card: CGFloat = 20
        static let sheet: CGFloat = 28
        static let row: CGFloat = 14
        /// An icon square, a logo square.
        static let tile: CGFloat = 12
        /// A chip, a day in the strip, an hour.
        static let chip: CGFloat = 11
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

        static var card: Shadow { Shadow(color: .black.opacity(0.05), radius: 10, y: 3) }
        static var floating: Shadow { Shadow(color: .black.opacity(0.18), radius: 18, y: 8) }
    }

    /// Text styles, all on the system's Dynamic Type styles: none has a fixed size.
    enum Typography {
        /// The athletic headline face (owner 2026-11-13, "more sports
        /// feeling", Nike / Under Armour / On): Sofia Sans Extra Condensed,
        /// black italic, scaling with Dynamic Type from `style`.
        static func display(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
            .custom("SofiaSansExtraCondensedItalic-BlackItalic", size: size, relativeTo: style)
        }

        /// The same family upright, for numbers that line up (scores, times).
        static func displayUpright(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
            .custom("SofiaSansExtraCondensed-ExtraBold", size: size, relativeTo: style)
        }

        static var wordmark: Font { display(40, relativeTo: .title) }
        static var headerTitle: Font { display(30, relativeTo: .title2) }
        static var sectionTitle: Font { display(28, relativeTo: .title2) }
        static var cardTitle: Font { display(30, relativeTo: .title2) }
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

private struct BrandPage: ViewModifier {
    @Environment(\.shellBarHeight) private var barHeight

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, Theme.Spacing.m, for: .scrollContent)
            // DEBUG only (`PLAYERZ_SCROLL_END=1`): open at the end, for a screenshot.
            .defaultScrollAnchor(DebugLaunch.scrollEnd ? .bottom : nil)
            .safeAreaPadding(.bottom, barHeight)
            .background(Theme.Palette.page.ignoresSafeArea())
    }
}

extension View {
    func themeShadow(_ shadow: Theme.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }

    /// The page colour behind a whole screen: a List or Form loses its own
    /// background and its tall first gap, so the first card starts one step
    /// under the band or the chips on every screen; a spinner or an empty
    /// state is stretched to fill.
    ///
    /// Its end stays clear of the floating bar (`shellBarHeight`): a list
    /// scrolls under the bar and still stops with its last row above it.
    func brandPage() -> some View {
        modifier(BrandPage())
    }

    /// A List's or Form's rows on the card token, with the token's hairline
    /// between them. On the rows (or a Group or Section of them), not on the
    /// List: the system's grey is otherwise a second card colour in dark mode.
    func brandListRow() -> some View {
        listRowBackground(Theme.Palette.card)
            .listRowSeparatorTint(Theme.Palette.hairline)
    }
}

#Preview("Palette") {
    let swatches: [(String, Color)] = [
        ("page", Theme.Palette.page), ("card", Theme.Palette.card),
        ("headerInk", Theme.Palette.headerInk), ("headerGlow", Theme.Palette.headerGlow),
        ("accentFill", Theme.Palette.accentFill), ("accentText", Theme.Palette.accentText),
        ("controlOn", Theme.Palette.controlOn),
        ("chipIdle", Theme.Palette.chipIdle), ("selectedFill", Theme.Palette.selectedFill), ("inverse", Theme.Palette.inverse),
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
