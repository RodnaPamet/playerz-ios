import SwiftUI

/// A row's title and the short note that ends its line (a time): side by
/// side while both fit whole, the note under the title when they do not.
/// The title is who or what the row is, so it is never the one cut short.
/// Unlike `ViewThatFits`, both forms are the same two views, and the note
/// stays at the line's end without a spacer.
struct BrandTitleLine: Layout {
    var spacing: CGFloat = Theme.Spacing.s
    var stackedSpacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let title = subviews[0].sizeThatFits(.unspecified)
        let note = subviews[1].sizeThatFits(.unspecified)
        let width = proposal.width ?? title.width + spacing + note.width
        if fitsOnOneLine(title, note, in: width) {
            return CGSize(width: width, height: max(title.height, note.height))
        }
        let wrapped = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let noteWrapped = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: wrapped.height + stackedSpacing + noteWrapped.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let title = subviews[0].sizeThatFits(.unspecified)
        let note = subviews[1].sizeThatFits(.unspecified)
        if fitsOnOneLine(title, note, in: bounds.width) {
            // On one baseline, the note at the line's end. (A Layout's
            // coordinates are mirrored for right-to-left by SwiftUI.)
            let titleBase = subviews[0].dimensions(in: .unspecified)[.firstTextBaseline]
            let noteBase = subviews[1].dimensions(in: .unspecified)[.firstTextBaseline]
            let base = max(titleBase, noteBase)
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + base - titleBase),
                anchor: .topLeading,
                proposal: .unspecified
            )
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + base - noteBase),
                anchor: .topTrailing,
                proposal: .unspecified
            )
        } else {
            let offer = ProposedViewSize(width: bounds.width, height: nil)
            let wrapped = subviews[0].sizeThatFits(offer)
            let x = bounds.minX
            let anchor: UnitPoint = .topLeading
            subviews[0].place(at: CGPoint(x: x, y: bounds.minY), anchor: anchor, proposal: offer)
            subviews[1].place(
                at: CGPoint(x: x, y: bounds.minY + wrapped.height + stackedSpacing),
                anchor: anchor,
                proposal: offer
            )
        }
    }

    private func fitsOnOneLine(_ title: CGSize, _ note: CGSize, in width: CGFloat) -> Bool {
        title.width + spacing + note.width <= width
    }
}
