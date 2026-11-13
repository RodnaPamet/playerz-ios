import SwiftUI

enum BrandActionCardStyle {
    /// The accent fill: the one tile to notice first.
    case accent
    /// A dark tile, in both modes.
    case dark
    /// A photo under a scrim that keeps the white text readable.
    case photo(Image)
    /// A sport's banner photo (SportBackdrop) under the draft's ink scrim:
    /// the hero of a sports page.
    case sport(String)
}

/// A large rounded tile for the home grid: an icon square, a title, a line
/// under it, and «Скоро» or another word on its corner.
///
/// It is a LABEL: wrap it in a Button or a NavigationLink with
/// `.buttonStyle(.brandCard)`. It reads as one element: title, subtitle, badge.
struct BrandActionCard: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var style: BrandActionCardStyle = .dark
    /// A word on the corner; `String(localized: "brand.comingSoon")` for «Скоро».
    var badge: String?
    var minHeight: CGFloat = 150
    /// True takes the height offered: two cards in a row end level.
    var fillsHeight = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(minWidth: 48, minHeight: 48)
                .background(iconFill, in: .rect(cornerRadius: Theme.Radius.tile))
                .accessibilityHidden(true)
            Spacer(minLength: Theme.Spacing.m)
            Text(title)
                .font(Theme.Typography.cardTitle)
                .textCase(.uppercase)
                .foregroundStyle(titleColor)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.cardSubtitle)
                    .foregroundStyle(titleColor.opacity(0.78))
            }
        }
        .multilineTextAlignment(.leading)
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background { background }
        .overlay(alignment: .topTrailing) {
            if let badge {
                BrandBadge(badge, style: isAccent ? .ink : .accent).padding(Theme.Spacing.m)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(isAccent ? .clear : Theme.Palette.photoEdge))
        // The dark and photo tiles are dark in both modes: the accent on them
        // takes its dark value.
        .environment(\.colorScheme, isAccent ? systemScheme : .dark)
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @Environment(\.colorScheme) private var systemScheme

    private var isAccent: Bool {
        if case .accent = style { true } else { false }
    }

    private var titleColor: Color { isAccent ? Theme.Palette.onAccent : .white }
    /// The draft's quiet icons: lavender on a violet square, except on the
    /// one accent tile.
    private var iconFill: Color { isAccent ? Theme.Palette.headerInk : Theme.Palette.selectedFill }
    private var iconColor: Color { isAccent ? .white : Theme.Palette.accentText }

    @ViewBuilder private var background: some View {
        switch style {
        case .accent:
            // The sunset of an action, at a slant across the tile.
            LinearGradient(
                colors: [Theme.Palette.accentFill, Theme.Palette.accentFillEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .dark:
            LinearGradient(
                colors: [Theme.Palette.sheetRow, Theme.Palette.sheetSurface],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
        case let .photo(image):
            image
                .resizable()
                .scaledToFill()
                .overlay(LinearGradient(
                    colors: [.black.opacity(0.25), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom
                ))
                .accessibilityHidden(true)
        case let .sport(sport):
            SportBackdrop(sport: sport)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            BrandActionCard(title: "Резервирай корт", subtitle: "За частна игра", systemImage: "sportscourt", style: .photo(Image(systemName: "photo")))
            HStack(spacing: 12) {
                BrandActionCard(title: "Създай игра", systemImage: "plus", style: .accent)
                BrandActionCard(title: "Открий игри и турнири", systemImage: "person.badge.plus")
            }
            BrandActionCard(title: "Запази урок", subtitle: "С треньор в клуб", systemImage: "figure.tennis", badge: "Скоро")
        }
        .padding()
    }
    .brandPage()
}
