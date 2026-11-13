import SwiftUI

/// What a bottom sheet holds: a title, a line under it, then rows
/// (`BrandSheetRow`) or anything else, on the dark surface. Present it with
/// `brandSheet(isPresented:)`, which gives the grabber, the dark background
/// and a height that hugs what is in here.
struct BrandDarkSheet<Content: View>: View {
    let title: String
    var subtitle: String?
    let content: Content

    /// Where `brandSheet` wants this sheet's height; nil in a preview.
    @Environment(\.brandSheetHeight) private var sheetHeight

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)
                content
            }
            .padding(.horizontal, Theme.Spacing.l)
            // Below the grabber.
            .padding(.top, Theme.Spacing.xl + Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            // A detent's height leaves out the home indicator's strip, as this does.
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight?.wrappedValue = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.Palette.sheetSurface.ignoresSafeArea())
        // Dark in both modes: the accent and system controls take dark values.
        .environment(\.colorScheme, .dark)
    }
}

/// A row in a dark sheet: an icon square, a title, a line under it.
///
/// `isSelected` nil is an action («Резервирай корт»). True or false is one of a
/// set of options: the chosen one is outlined in the accent and ticked, the
/// others have a muted icon.
struct BrandSheetRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    var badge: String?
    var isSelected: Bool?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected == false ? Color.white : Theme.Palette.onAccent)
                    .frame(minWidth: 48, minHeight: 48)
                    .background(
                        isSelected == false ? Color.white.opacity(0.1) : Theme.Palette.accentFill,
                        in: .rect(cornerRadius: Theme.Radius.tile)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.rowTitle)
                        .foregroundStyle(.white)
                    if let badge {
                        BrandBadge(badge)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.s)
                if isSelected == true {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.accentFill)
                        .accessibilityHidden(true)
                }
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
            .overlay {
                if isSelected == true {
                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                        .strokeBorder(Theme.Palette.accentFill, lineWidth: 2)
                }
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.row))
        }
        .buttonStyle(.brandCard)
        .accessibilityAddTraits(isSelected == true ? .isSelected : [])
        .environment(\.colorScheme, .dark)
    }
}

private struct BrandSheetHeightKey: EnvironmentKey {
    static var defaultValue: Binding<CGFloat>? { nil }
}

extension EnvironmentValues {
    /// Set by `brandSheet`; a `BrandDarkSheet` writes its height here.
    fileprivate var brandSheetHeight: Binding<CGFloat>? {
        get { self[BrandSheetHeightKey.self] }
        set { self[BrandSheetHeightKey.self] = newValue }
    }
}

/// The sheet's chrome around its content. With no `detents` the sheet is as
/// tall as its `BrandDarkSheet` (two rows are not half a screen), up to the
/// whole screen, where the content scrolls.
private struct BrandSheetPresentation<Content: View>: View {
    let detents: Set<PresentationDetent>?
    let content: Content

    @State private var height: CGFloat = 0

    var body: some View {
        content
            .environment(\.brandSheetHeight, $height)
            .outsideShellBar()
            .presentationDetents(resolved)
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Palette.sheetSurface)
            .presentationCornerRadius(Theme.Radius.sheet)
            .environment(\.colorScheme, .dark)
    }

    private var resolved: Set<PresentationDetent> {
        if let detents { return detents }
        // Not measured yet, or not a BrandDarkSheet inside.
        return height > 0 ? [.height(height)] : [.medium, .large]
    }
}

extension View {
    /// A dark bottom sheet with a grabber; `content` is a `BrandDarkSheet`.
    /// `detents` nil hugs the content; give a set to choose the heights.
    func brandSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent>? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            BrandSheetPresentation(detents: detents, content: content())
        }
    }

    /// The same, for a sheet that shows one thing of several.
    func brandSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent>? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            BrandSheetPresentation(detents: detents, content: content(item))
        }
    }
}

#Preview("Actions") {
    BrandDarkSheet(title: "Създай", subtitle: "Какво искаш да направиш?") {
        BrandSheetRow(title: "Резервирай корт", subtitle: "Избери клуб и свободен час", systemImage: "calendar") {}
        BrandSheetRow(title: "Запази урок", subtitle: "С треньор", systemImage: "figure.tennis", badge: "Скоро") {}
    }
}

#Preview("Options") {
    BrandDarkSheet(title: "Избери спорт") {
        BrandSheetRow(title: "Падел", systemImage: "sportscourt", isSelected: true) {}
        BrandSheetRow(title: "Тенис", systemImage: "tennisball", isSelected: false) {}
    }
}
