import SwiftUI

/// What the header band leads with.
enum BrandHeaderLeading {
    /// «playerz»: a tab's first screen.
    case wordmark
    /// A screen's name, with nothing to go back to.
    case title(String)
    /// A round back button, then the screen's name. The button pops, or
    /// closes a presented first screen, unless `action` says otherwise.
    case back(String, action: (@MainActor () -> Void)? = nil)
}

/// The dark band at the top of a screen: the wordmark or a title, then a pill
/// (`accessory`: the sport picker's place) and round buttons (`actions`: the
/// bell, messages).
///
/// Use it through `brandHeader(_:)`, which hides the system bar and keeps the
/// safe area right. When the row does not fit (a long title, a large text
/// size) the pill moves to a second row instead of clipping.
struct BrandHeader<Accessory: View, Actions: View>: View {
    let leading: BrandHeaderLeading
    let accessory: Accessory
    let actions: Actions

    @Environment(\.dismiss) private var dismiss

    // Both closures are required and labelled here: with defaults, a single
    // trailing closure would bind to the first one. The modifiers below give
    // the short forms.
    init(
        _ leading: BrandHeaderLeading,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder actions: () -> Actions
    ) {
        self.leading = leading
        self.accessory = accessory()
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.s) {
                lead(lines: 1)
                Spacer(minLength: Theme.Spacing.s)
                // At its full width or not at all: a pill squeezed to «С…»
                // would "fit", and the second row would never be used.
                accessory.fixedSize(horizontal: true, vertical: false)
                actions
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    lead(lines: 3)
                    Spacer(minLength: Theme.Spacing.s)
                    actions
                }
                accessory
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BrandHeaderBackdrop().ignoresSafeArea(edges: [.top, .horizontal]) }
        // Dark in both modes, so everything on it resolves its dark values.
        .environment(\.colorScheme, .dark)
        // The band is chrome: past this size it would take the screen from
        // the content, and the title is shown by the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder private func lead(lines: Int) -> some View {
        switch leading {
        case .wordmark:
            // The brand's name, the same in every language.
            Text(verbatim: "playerz")
                .font(Theme.Typography.wordmark)
                .foregroundStyle(Theme.Palette.onHeader)
                .lineLimit(1)
                .frame(minHeight: Theme.minTarget)
                .accessibilityAddTraits(.isHeader)
        case let .title(title):
            self.title(title, lines: lines)
        case let .back(title, action):
            HStack(spacing: Theme.Spacing.m) {
                BrandHeaderButton(systemImage: "chevron.left", label: String(localized: "brand.back")) {
                    if let action { action() } else { dismiss() }
                }
                self.title(title, lines: lines)
            }
        }
    }

    /// An empty title draws nothing: a screen whose name is on its cover card
    /// passes "" until the card scrolls away, and VoiceOver must not stop on a blank.
    @ViewBuilder private func title(_ title: String, lines: Int) -> some View {
        if !title.isEmpty {
            Text(title)
                .font(Theme.Typography.headerTitle)
                // Capitals, as a sports page sets its headlines.
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.onHeader)
                .lineLimit(lines)
                .frame(minHeight: Theme.minTarget)
                .accessibilityAddTraits(.isHeader)
                .accessibilityShowsLargeContentViewer()
        }
    }
}

/// VoiceOver's two-finger scrub does what the band's back button does: the
/// system bar that would answer it is hidden, and a first screen with its own
/// `action` (the inbox) has nothing else to answer it.
private struct BrandHeaderEscape: ViewModifier {
    let leading: BrandHeaderLeading
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        if case let .back(_, action) = leading {
            content.accessibilityAction(.escape) {
                if let action { action() } else { dismiss() }
            }
        } else {
            content
        }
    }
}

extension View {
    /// The header band on top of this screen, in place of the system bar. On
    /// the content INSIDE a NavigationStack, after any other top inset (a chip
    /// row), so the band comes first.
    func brandHeader(_ leading: BrandHeaderLeading) -> some View {
        brandHeader(leading, accessory: { EmptyView() }, actions: { EmptyView() })
    }

    /// The band with round buttons at its end (`BrandHeaderButton`s).
    func brandHeader<Actions: View>(
        _ leading: BrandHeaderLeading,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        brandHeader(leading, accessory: { EmptyView() }, actions: actions)
    }

    /// The band with a pill (`BrandHeaderPill`) before its round buttons.
    func brandHeader<Accessory: View, Actions: View>(
        _ leading: BrandHeaderLeading,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                BrandHeader(leading, accessory: accessory, actions: actions)
            }
            .modifier(BrandHeaderEscape(leading: leading))
    }
}

#Preview("Wordmark") {
    NavigationStack {
        List(0..<20, id: \.self) { Text(verbatim: "Ред \($0)") }
            .brandHeader(.wordmark) {
                BrandHeaderPill(title: "Падел", systemImage: "sportscourt", showsChevron: true) {}
            } actions: {
                BrandHeaderButton(systemImage: "bell", label: "Известия", badge: .count(2)) {}
            }
    }
}

#Preview("Back") {
    NavigationStack {
        Color.clear.brandPage().brandHeader(.back("Частна игра"))
    }
}
