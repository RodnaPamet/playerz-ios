import SwiftUI

extension View {
    /// A List or Form row with no box of its own: a card, a chip row or a
    /// full-width brand button that sits on the page colour, as wide as the
    /// cards around it. On the Section, so its rows and spacing follow suit.
    func bareListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
