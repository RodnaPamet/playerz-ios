import SwiftUI

extension View {
    /// A List row that holds only a pill button (`.brandPrimary`): no card box
    /// around it and no hairline, so the pill sits on the page as it does on
    /// a screen of cards, the width of the rows above it.
    func listPillRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
