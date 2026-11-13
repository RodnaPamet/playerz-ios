import SwiftUI

/// One item of the floating bar.
struct BrandTabItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let systemImage: String
    /// Unread things behind this tab; 0 shows nothing.
    var badge = 0
}

/// The floating bar: a rounded bar clear of the screen's edges, the selected
/// item on an accent pill, and a round button in the middle that opens
/// something instead of selecting a tab.
///
/// VoiceOver reads the items as tabs, the selected one as selected. The bar
/// is chrome: its text does not grow past the default size, and the system's
/// large content viewer shows an item on a long press, as on the system's bar.
struct BrandTabBar<ID: Hashable>: View {
    @Binding var selection: ID
    /// Before the centre button, and after it.
    let leading: [BrandTabItem<ID>]
    let trailing: [BrandTabItem<ID>]
    let centerLabel: String
    var centerSystemImage = "plus"
    let onCenter: () -> Void
    /// The selected item tapped again.
    var onReselect: ((ID) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leading) { item($0) }
            center
            ForEach(trailing) { item($0) }
        }
        .padding(6)
        .background(Theme.Palette.card, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
        .themeShadow(.floating)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.xs)
        // Four words share one line and there is no room for them to grow:
        // past this size, the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    private func item(_ item: BrandTabItem<ID>) -> some View {
        let selected = item.id == selection
        return Button {
            if selected {
                onReselect?(item.id)
            } else if reduceMotion {
                selection = item.id
            } else {
                withAnimation(.snappy(duration: 0.25)) { selection = item.id }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.systemImage)
                    .symbolVariant(selected ? .fill : .none)
                    .font(.body.weight(.semibold))
                    .overlay(alignment: .topTrailing) {
                        if item.badge > 0 {
                            Circle()
                                .fill(Theme.Palette.badge)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Theme.Palette.card, lineWidth: 1.5))
                                .offset(x: 6, y: -4)
                        }
                    }
                // Its own width, so the longest word («Резервации») takes
                // more of the bar than the short ones instead of shrinking or
                // touching the pill's edge; the others share what is left.
                Text(item.title)
                    .font(Theme.Typography.tabLabel)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
            }
            .foregroundStyle(selected ? Theme.Palette.accentText : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if selected {
                    Capsule().fill(Theme.Palette.selectedFill).matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.badge > 0 ? "\(item.badge)" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer { Label(item.title, systemImage: item.systemImage) }
    }

    private var center: some View {
        Button(action: onCenter) {
            Image(systemName: centerSystemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.Palette.onInverse)
                .frame(minWidth: 52, minHeight: 52)
                .background(Theme.Palette.inverse, in: .circle)
                .overlay(Circle().strokeBorder(Theme.Palette.accentFill, lineWidth: 2))
                // The circle's own width, not an equal share: the words get the rest.
                .padding(.horizontal, Theme.Spacing.xs)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(centerLabel)
        .accessibilityShowsLargeContentViewer { Label(centerLabel, systemImage: centerSystemImage) }
    }
}

#Preview {
    struct Demo: View {
        @State private var tab = "home"
        var body: some View {
            Color.clear.brandPage().safeAreaInset(edge: .bottom) {
                BrandTabBar(
                    selection: $tab,
                    leading: [
                        .init(id: "home", title: "Начало", systemImage: "house"),
                        .init(id: "explore", title: "Открий", systemImage: "magnifyingglass"),
                    ],
                    trailing: [
                        .init(id: "bookings", title: "Резервации", systemImage: "calendar", badge: 2),
                        .init(id: "profile", title: "Профил", systemImage: "person.crop.circle"),
                    ],
                    centerLabel: "Създай",
                    onCenter: {}
                )
            }
        }
    }
    return Demo()
}
