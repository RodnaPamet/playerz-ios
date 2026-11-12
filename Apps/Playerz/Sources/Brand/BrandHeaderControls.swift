import SwiftUI

/// What a round header button carries on its corner.
enum BrandHeaderBadge: Equatable {
    case none
    /// Something is unread, without saying how much.
    case dot
    case count(Int)
}

/// A round button on the header band: the bell, messages, back, «още».
///
/// `label` is the whole VoiceOver label, the badge's meaning included
/// («Известия, 3 непрочетени»): the badge itself is not read.
struct BrandHeaderButton: View {
    let systemImage: String
    let label: String
    var badge: BrandHeaderBadge = .none
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.onHeader)
                .padding(Theme.Spacing.s)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .background(.white.opacity(0.14), in: .circle)
                .overlay(alignment: .topTrailing) { badgeView }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        // A larger text size shows the name instead of growing the band.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: systemImage) }
    }

    @ViewBuilder private var badgeView: some View {
        switch badge {
        case .none:
            EmptyView()
        case .dot:
            Circle()
                .fill(Theme.Palette.badge)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.Palette.headerInk, lineWidth: 2))
        case let .count(count):
            Text(count > 99 ? "99+" : "\(count)")
                .font(Theme.Typography.badge)
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.onBadge)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Theme.Palette.badge, in: .capsule)
                .offset(x: 4, y: -4)
        }
    }
}

/// The pill in the header: the sport picker, or a link («Треньори»). The
/// label alone, for a Menu or a NavigationLink; `BrandHeaderPill` is the button.
struct BrandHeaderPillLabel: View {
    let title: String
    var systemImage: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.Palette.onAccent)
                    .padding(6)
                    .background(Theme.Palette.accentFill, in: .circle)
            }
            Text(title)
                .font(Theme.Typography.chip)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
        }
        .foregroundStyle(Theme.Palette.onHeader)
        .padding(.leading, systemImage == nil ? Theme.Spacing.l : Theme.Spacing.s)
        .padding(.trailing, Theme.Spacing.l)
        .frame(minHeight: Theme.minTarget)
        .background(.white.opacity(0.14), in: .capsule)
        // The band is dark in both modes: the accent takes its dark value.
        .environment(\.colorScheme, .dark)
    }
}

struct BrandHeaderPill: View {
    let title: String
    var systemImage: String?
    var showsChevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BrandHeaderPillLabel(title: title, systemImage: systemImage, showsChevron: showsChevron)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        BrandHeaderPill(title: "Падел", systemImage: "sportscourt", showsChevron: true) {}
        BrandHeaderButton(systemImage: "bubble.left", label: "Съобщения", badge: .dot) {}
        BrandHeaderButton(systemImage: "bell", label: "Известия", badge: .count(3)) {}
    }
    .padding()
    .background(BrandHeaderBackdrop())
}
