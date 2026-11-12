import SwiftUI

/// The screen's one main action: a full-width accent pill.
struct BrandPrimaryButtonStyle: ButtonStyle {
    /// False hugs the label, for a button inside a card or an empty state.
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        BrandPillButton(configuration: configuration, fullWidth: fullWidth, filled: true)
    }
}

/// An action beside or below the main one: the same pill, outlined.
struct BrandSecondaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        BrandPillButton(configuration: configuration, fullWidth: fullWidth, filled: false)
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: BrandPrimaryButtonStyle { .init() }
    static func brandPrimary(fullWidth: Bool) -> BrandPrimaryButtonStyle { .init(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == BrandSecondaryButtonStyle {
    static var brandSecondary: BrandSecondaryButtonStyle { .init() }
    static func brandSecondary(fullWidth: Bool) -> BrandSecondaryButtonStyle { .init(fullWidth: fullWidth) }
}

/// A view, not the style itself: only a view reads `isEnabled` reliably.
private struct BrandPillButton: View {
    let configuration: ButtonStyleConfiguration
    let fullWidth: Bool
    let filled: Bool

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Typography.button)
            .multilineTextAlignment(.center)
            .foregroundStyle(filled ? Theme.Palette.onAccent : Theme.Palette.accentText)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .background {
                if filled {
                    Capsule().fill(Theme.Palette.accentFill)
                } else {
                    Capsule().strokeBorder(Theme.Palette.accentText, lineWidth: 1.5)
                }
            }
            .contentShape(.capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

/// For a card that is a button or a link: it dims when pressed, and sinks a
/// little unless Reduce Motion is on.
struct BrandCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BrandPressedCard(configuration: configuration)
    }
}

extension ButtonStyle where Self == BrandCardButtonStyle {
    static var brandCard: BrandCardButtonStyle { .init() }
}

private struct BrandPressedCard: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button(String("Покажи резултатите")) {}.buttonStyle(.brandPrimary)
        Button(String("Изчисти")) {}.buttonStyle(.brandSecondary)
        Button(String("Опитай пак")) {}.buttonStyle(.brandSecondary(fullWidth: false))
        Button(String("Недостъпен")) {}.buttonStyle(.brandPrimary).disabled(true)
    }
    .padding()
}
