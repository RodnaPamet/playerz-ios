import SwiftUI

enum BrandActionCardStyle {
    /// The accent fill: the one tile to notice first.
    case accent
    /// A dark tile, in both modes.
    case dark
    /// A photo under a scrim that keeps the white text readable.
    case photo(Image)
    /// A sport's surface (SportPitch), leaning, under the same scrim: the
    /// campaign banner of a sports page.
    case pitch(String)
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(.white.opacity(isAccent ? 0 : 0.08)))
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
    private var iconFill: Color { isAccent ? Theme.Palette.headerInk : Theme.Palette.accentFill }
    private var iconColor: Color { isAccent ? .white : Theme.Palette.onAccent }

    @ViewBuilder private var background: some View {
        switch style {
        case .accent:
            Theme.Palette.accentFill
        case .dark:
            LinearGradient(
                colors: [Theme.Palette.sheetRow, Theme.Palette.headerInk],
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
        case let .pitch(sport):
            Color.black
                .overlay {
                    SportPitchView(sport: sport, rounded: false)
                        .scaleEffect(1.5)
                        .rotationEffect(.degrees(-12))
                        .offset(x: 70)
                }
                .overlay(LinearGradient(
                    colors: [.black.opacity(0.78), .black.opacity(0.35), .black.opacity(0.1)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .clipped()
                .accessibilityHidden(true)
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
