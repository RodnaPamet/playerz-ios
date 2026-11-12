import SwiftUI

/// What a bottom sheet holds: a title, a line under it, then rows
/// (`BrandSheetRow`) or anything else, on the dark surface. Present it with
/// `brandSheet(isPresented:)`, which gives the grabber, the detents and the
/// dark background.
struct BrandDarkSheet<Content: View>: View {
    let title: String
    var subtitle: String?
    let content: Content

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

extension View {
    /// A dark bottom sheet with a grabber; `content` is a `BrandDarkSheet`.
    func brandSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content().brandSheetPresentation(detents: detents)
        }
    }

    /// The same, for a sheet that shows one thing of several.
    func brandSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = [.medium, .large],
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item).brandSheetPresentation(detents: detents)
        }
    }

    fileprivate func brandSheetPresentation(detents: Set<PresentationDetent>) -> some View {
        presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Palette.sheetSurface)
            .presentationCornerRadius(Theme.Radius.sheet)
            .environment(\.colorScheme, .dark)
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
