import SwiftUI

/// A fact about a venue as a small capsule: a sport, the rating, the price.
struct VenueFactChip: View {
    let text: String
    var systemImage: String?
    /// True for the one to notice first: the price.
    var prominent = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(prominent ? Theme.Palette.onAccent : Color.primary)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 6)
        .background(prominent ? AnyShapeStyle(Theme.Palette.actionFill) : AnyShapeStyle(Theme.Palette.chipIdle), in: .capsule)
    }
}
