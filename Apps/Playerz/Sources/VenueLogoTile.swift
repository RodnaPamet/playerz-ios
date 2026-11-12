import SwiftUI

/// The square that overlaps a cover's lower edge: the club's logo when the
/// server has one (only a club's page does), else its initial.
struct VenueLogoTile: View {
    let name: String
    var logoURL: URL?

    var body: some View {
        initial.overlay {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .clipped()
    }

    private var initial: some View {
        LinearGradient(
            colors: [Theme.Palette.headerInk, Theme.Palette.headerGlow],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Text(verbatim: name.first.map { String($0).uppercased() } ?? "")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.Palette.onHeader)
                .minimumScaleFactor(0.5)
        }
    }
}
