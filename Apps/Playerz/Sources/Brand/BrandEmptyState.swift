import SwiftUI

/// Nothing to show, said kindly: a round icon, an optional badge word
/// («Скоро»), a title, a sentence, and room for a button. In place of
/// ContentUnavailableView on restyled screens. It fills the space it is given,
/// and scrolls when the text is larger than that; it is for a page's whole
/// content area, not for the inside of another scroll view.
struct BrandEmptyState<Actions: View>: View {
    let systemImage: String
    let title: String
    var message: String?
    var badge: String?
    let actions: Actions

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        badge: String? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.badge = badge
        self.actions = actions()
    }

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The room the page gives: the stack is at least this tall, so it sits
    /// in the middle while it fits and scrolls from the top when it does not.
    @State private var room: CGFloat = 0

    var body: some View {
        // Always a scroll view, measured, not `ViewThatFits`: that one chose
        // the unscrolling stack at the largest text sizes and left the last
        // lines under the tab bar.
        ScrollView {
            stack
                // Past the floating bar's shadow, so the last line ends clear of it.
                .padding(.bottom, Theme.Spacing.l)
                .frame(maxWidth: .infinity, minHeight: room)
        }
        .scrollBounceBehavior(.basedOnSize)
        // DEBUG only (`PLAYERZ_EMPTY_END=1`): open at the end, for a screenshot.
        .defaultScrollAnchor(DebugLaunch.emptyStateEnd ? .bottom : .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { room = $0 }
    }

    private var stack: some View {
        // At the accessibility sizes the words need the room: the picture,
        // which says nothing the title does not, gets smaller and the
        // margins tighter.
        let roomy = !typeSize.isAccessibilitySize
        return VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(roomy ? .largeTitle : .title3)
                .foregroundStyle(Color.primary)
                .padding(roomy ? Theme.Spacing.xl : Theme.Spacing.m)
                .frame(minWidth: roomy ? 96 : 56, minHeight: roomy ? 96 : 56)
                .background(Theme.Palette.chipIdle, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.s) {
                if let badge {
                    BrandBadge(badge, style: .ink)
                }
                Text(title)
                    .font(Theme.Typography.sectionTitle)
                if let message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            // Each line as tall as it needs: never squeezed to fit the screen.
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            actions.padding(.top, Theme.Spacing.s)
        }
        .padding(roomy ? Theme.Spacing.xl : Theme.Spacing.l)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BrandEmptyState(
        systemImage: "trophy",
        title: "Турнирите идват",
        message: "Ще ти кажем, щом се отворят.",
        badge: "Скоро"
    ) {
        Button(String("Опитай пак")) {}.buttonStyle(.brandSecondary(fullWidth: false))
    }
    .brandPage()
}
