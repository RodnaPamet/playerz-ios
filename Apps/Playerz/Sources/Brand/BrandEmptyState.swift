import SwiftUI

/// Nothing to show, said kindly: a round icon, an optional badge word
/// («Скоро»), a title, a sentence, and room for a button. In place of
/// ContentUnavailableView on restyled screens. It fills the space it is given,
/// and scrolls when the text is larger than that.
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

    var body: some View {
        ViewThatFits(in: .vertical) {
            stack
            ScrollView { stack }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stack: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color.primary)
                .padding(Theme.Spacing.xl)
                .frame(minWidth: 96, minHeight: 96)
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
            .accessibilityElement(children: .combine)
            actions.padding(.top, Theme.Spacing.s)
        }
        .padding(Theme.Spacing.xl)
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
