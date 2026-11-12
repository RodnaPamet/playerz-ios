import SwiftUI

/// Who is signed in, at the top of Профил: the picture or the initials, the
/// name, the email, and each sport's level when the server gives one.
struct ProfileIdentityCard: View {
    let name: String
    let email: String
    let avatarURL: URL?
    /// «Падел · Ниво 4,0», one per sport.
    let levels: [String]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        BrandContentCard {
            // The picture above the words at the accessibility sizes, so the
            // name has the card's width.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.m))
                : AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Spacing.l))
            layout {
                BrandAvatar(name: name, url: avatarURL, side: 64)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(name)
                        .font(Theme.Typography.cardTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(Self.breakable(email))
                        .font(Theme.Typography.cardSubtitle)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(email)
                    ForEach(levels, id: \.self) { level in
                        Text(level)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, Theme.Spacing.s)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Palette.chipIdle, in: .rect(cornerRadius: Theme.Spacing.s))
                            // Wraps whole at the large sizes rather than running off the card.
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// An address that may break only after «@» and before a dot: at the large
    /// sizes «ivan-iosdemo@play/erz.test» broke inside a word. A zero-width
    /// space marks each place; VoiceOver reads the plain address.
    static func breakable(_ email: String) -> String {
        let gap = String(Character(Unicode.Scalar(0x200B)!))
        return email
            .replacingOccurrences(of: "@", with: "@" + gap)
            .replacingOccurrences(of: ".", with: gap + ".")
    }
}

/// One of the tiles under the name: where the player's own things are.
struct ProfileHubTile: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    /// Unread, from the server; 0 shows nothing.
    var count = 0
    /// What VoiceOver says in place of the title when something is unread.
    var spokenCount: String?
    /// A count that is not an alert (bookings ahead): the accent, not the
    /// red of unread.
    var calm = false
    let action: () -> Void
}

/// The tiles in a row; one under the other when their words do not fit
/// side by side (a narrow phone, a large text size).
struct ProfileHubTiles: View {
    let tiles: [ProfileHubTile]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(tiles) { tile in
                    button(tile) {
                        VStack(spacing: Theme.Spacing.s) {
                            icon(tile)
                            Text(tile.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.vertical, Theme.Spacing.l)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            VStack(spacing: Theme.Spacing.s) {
                ForEach(tiles) { tile in
                    button(tile) {
                        HStack(spacing: Theme.Spacing.m) {
                            icon(tile)
                            Text(tile.title).font(Theme.Typography.rowTitle)
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Spacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func button(_ tile: ProfileHubTile, @ViewBuilder label: () -> some View) -> some View {
        Button(action: tile.action) {
            label()
                .frame(minHeight: Theme.minTarget)
                .brandCardSurface()
        }
        .buttonStyle(.brandCard)
        .accessibilityLabel(tile.title)
        .accessibilityValue(tile.count > 0 ? (tile.spokenCount ?? "\(tile.count)") : "")
    }

    private func icon(_ tile: ProfileHubTile) -> some View {
        Image(systemName: tile.systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.Palette.accentText)
            .frame(minWidth: 32, minHeight: 28)
            .overlay(alignment: .topTrailing) {
                if tile.count > 0 {
                    Text("\(tile.count)")
                        .font(Theme.Typography.badge)
                        .monospacedDigit()
                        .foregroundStyle(tile.calm ? Theme.Palette.onAccent : Theme.Palette.onBadge)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(tile.calm ? Theme.Palette.accentFill : Theme.Palette.badge, in: .capsule)
                        .offset(x: 10, y: -8)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A row of a hub group: an icon in a circle, a title, a line under it, and
/// what the row ends with (a chevron for a row that opens something).
struct ProfileHubRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var tint: Color = .primary
    let trailing: Trailing

    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 40

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color = .primary,
        @ViewBuilder trailing: () -> Trailing = {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: min(iconSide, 56), height: min(iconSide, 56))
                .background(Theme.Palette.chipIdle, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(tint)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: Theme.Spacing.s)
            trailing
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Rows of the hub as one rounded card, with a hairline between them.
struct ProfileHubGroup<Rows: View>: View {
    var title: String?
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .font(Theme.Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            // `Group(subviews:)` is iOS 18; `_VariadicView` is private. The
            // rows put their own hairline on top instead (`hubDivider()`).
            VStack(spacing: 0) { rows }
                .brandCardSurface()
        }
    }
}

extension View {
    /// The hairline above a hub row that is not its group's first.
    func hubDivider() -> some View {
        overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Palette.hairline)
                .frame(height: 1)
                .padding(.leading, Theme.Spacing.l)
        }
    }
}
