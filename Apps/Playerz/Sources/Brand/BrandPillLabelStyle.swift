import SwiftUI

/// A pill's icon and title, the title alone at the accessibility sizes: beside
/// the icon «Покани играчи» broke mid-word and was cut off.
struct BrandPillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        PillLabel(configuration: configuration)
    }

    private struct PillLabel: View {
        let configuration: LabelStyleConfiguration
        @Environment(\.dynamicTypeSize) private var typeSize

        var body: some View {
            if typeSize.isAccessibilitySize {
                configuration.title
            } else {
                HStack(spacing: Theme.Spacing.s) {
                    configuration.icon
                    configuration.title
                }
            }
        }
    }
}

extension LabelStyle where Self == BrandPillLabelStyle {
    /// For a Label inside a `.brandPrimary` / `.brandSecondary` pill.
    static var brandPill: BrandPillLabelStyle { BrandPillLabelStyle() }
}
