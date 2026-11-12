import SwiftUI

/// The card a list item sits in: the card surface, a large radius, a soft
/// shadow. Wrap it in a Button or a NavigationLink with `.buttonStyle(.brandCard)`.
struct BrandContentCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = Theme.Spacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCardSurface()
    }
}

/// A card under a cover picture, with a logo square that overlaps the
/// picture's lower edge: a club in a list.
///
/// `cover` is stretched to the card's width and `coverHeight`, and clipped: give
/// it a resizable, filling image or a colour. `logo` is clipped to a square.
/// `content` starts below the logo.
struct BrandCoverCard<Cover: View, Logo: View, Content: View>: View {
    var coverHeight: CGFloat
    /// What the cover shows, for VoiceOver (a photo's alt text); nil hides a
    /// cover that is only decoration.
    var coverLabel: String?
    let cover: Cover
    let logo: Logo
    let content: Content

    /// Grows with the text size, so the logo keeps its place beside larger text.
    @ScaledMetric(relativeTo: .title3) private var scaledLogoSide: CGFloat = 64
    /// To a point: at the largest sizes an uncapped tile was half the card's
    /// width and pushed the name it stands for off the first screen.
    private var logoSide: CGFloat { min(scaledLogoSide, 96) }

    init(
        coverHeight: CGFloat = 160,
        coverLabel: String? = nil,
        @ViewBuilder cover: () -> Cover,
        @ViewBuilder logo: () -> Logo,
        @ViewBuilder content: () -> Content
    ) {
        self.coverHeight = coverHeight
        self.coverLabel = coverLabel
        self.cover = cover()
        self.logo = logo()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
                .frame(maxWidth: .infinity, minHeight: coverHeight, maxHeight: coverHeight)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(coverLabel ?? "")
                .accessibilityAddTraits(.isImage)
                .accessibilityHidden(coverLabel?.isEmpty ?? true)
            content
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
                .padding(.top, logoSide / 2 + Theme.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topLeading) {
            logo
                .frame(width: logoSide, height: logoSide)
                .background(Theme.Palette.card)
                .clipShape(.rect(cornerRadius: Theme.Radius.tile))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(Theme.Palette.card, lineWidth: 3))
                .themeShadow(.card)
                .padding(.leading, Theme.Spacing.l)
                .offset(y: coverHeight - logoSide / 2)
                .accessibilityHidden(true)
        }
        .brandCardSurface()
    }
}

extension View {
    /// The card's surface, clip and shadow, for a card built by hand.
    func brandCardSurface() -> some View {
        background(Theme.Palette.card)
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            // In dark mode a shadow shows nothing; the hairline keeps the edge.
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
            .themeShadow(.card)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            BrandContentCard {
                Text(verbatim: "Днес, 14:00 – 15:00").font(Theme.Typography.rowTitle)
                Text(verbatim: "Корт 1 · София").foregroundStyle(.secondary)
            }
            BrandCoverCard {
                LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            } logo: {
                Image(systemName: "sportscourt.fill").font(.title2)
            } content: {
                Text(verbatim: "Падел Арена").font(Theme.Typography.cardTitle)
                Text(verbatim: "Петрич").foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    .brandPage()
}
