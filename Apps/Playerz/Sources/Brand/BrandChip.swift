import SwiftUI

/// A filter pill: accent fill when selected. Also a tick when the user asks
/// for differences that are not colour alone.
struct BrandChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor

    init(_ title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected && withoutColor {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                } else if let systemImage {
                    Image(systemName: systemImage).font(.footnote.weight(.semibold))
                }
                Text(title).font(Theme.Typography.chip).lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.Palette.onAccent : Color.primary)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(isSelected ? Theme.Palette.chipSelected : Theme.Palette.chipIdle, in: .capsule)
            // The pill is shorter than a finger; the target is not.
            .frame(minHeight: Theme.minTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // The chip stops growing with the bar it sits in (BrandChipRow); a
        // long press shows its word at full size.
        .accessibilityShowsLargeContentViewer {
            if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
        }
    }
}

/// Chips in a row that scrolls sideways, and, pinned at its end, `trailing`:
/// the filter button.
struct BrandChipRow<Chips: View, Trailing: View>: View {
    let chips: Chips
    let trailing: Trailing

    init(@ViewBuilder chips: () -> Chips, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.chips = chips()
        self.trailing = trailing()
    }

    @Environment(\.layoutDirection) private var direction

    /// Whether something is pinned at the row's end.
    private var hasTrailing: Bool { Trailing.self != EmptyView.self }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.s) { chips }
                    .padding(.leading, Theme.Spacing.l)
                    // Room to scroll the last chip out from under the fade.
                    .padding(.trailing, hasTrailing ? Theme.Spacing.xl : Theme.Spacing.l)
            }
            .scrollIndicators(.hidden)
            // Beside a pinned control a chip leaves by fading out: cut off
            // square against the filter button it read as a broken pill.
            .mask { if hasTrailing { edgeFade } else { Rectangle() } }
            trailing.padding(.trailing, Theme.Spacing.l)
        }
        // A bar, like the header band: past this size one chip would take the
        // whole row and push the filter button off. Each chip offers the
        // large content viewer instead.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var edgeFade: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: Theme.Spacing.xl)
        }
        // The mask is drawn, not laid out: mirror it by hand for right-to-left.
        .scaleEffect(x: direction == .rightToLeft ? -1 : 1)
    }
}

extension View {
    /// A chip row pinned under the header band, on the page colour. Before
    /// `brandHeader`, so the band comes first. The gap above is the same step
    /// `brandPage()` leaves below (a chip's 44pt target already holds 4pt of
    /// air on each side of the pill).
    func brandChipBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            bar()
                .padding(.top, Theme.Spacing.m)
                .background(Theme.Palette.page)
        }
    }
}

/// The filter button's face: sliders, and how many filters are on. The label
/// alone, for a Menu; `BrandFilterButton` is the button.
struct BrandFilterLabel: View {
    let count: Int

    var body: some View {
        Image(systemName: "slider.horizontal.3")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.Typography.badge)
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.onBadge)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Theme.Palette.badge, in: .capsule)
                }
            }
            .contentShape(.rect)
    }
}

/// Opens the filters; `count` is how many are on, read as the button's value.
struct BrandFilterButton: View {
    let label: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) { BrandFilterLabel(count: count) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(count > 0 ? "\(count)" : "")
    }
}

#Preview {
    BrandChipRow {
        BrandChip("12 ное", isSelected: true) {}
        BrandChip("Цял ден", isSelected: false) {}
        BrandChip("Всички градове", systemImage: "mappin", isSelected: false) {}
    } trailing: {
        BrandFilterButton(label: "Филтри", count: 1) {}
    }
}
