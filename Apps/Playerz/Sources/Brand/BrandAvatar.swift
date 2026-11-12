import SwiftUI

/// Who a row is about, as a circle: their picture when the server has one,
/// their initials otherwise; `systemImage` instead for what is not a person
/// (a club, a game's group chat). Decoration: the name is always beside it.
struct BrandAvatar: View {
    let name: String?
    var url: URL?
    var systemImage: String?

    /// Grows with the text beside it, up to a point: at the largest sizes
    /// the words need the row's width more than the picture does.
    @ScaledMetric private var scaled: CGFloat

    init(name: String?, url: URL? = nil, systemImage: String? = nil, side: CGFloat = 44) {
        self.name = name
        self.url = url
        self.systemImage = systemImage
        _scaled = ScaledMetric(wrappedValue: side, relativeTo: .headline)
        base = side
    }

    private let base: CGFloat
    private var side: CGFloat { min(scaled, base * 1.5) }

    var body: some View {
        ZStack {
            Theme.Palette.chipIdle
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        // Loading, or the picture is gone: the initials stand in.
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: side, height: side)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var fallback: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: side * 0.4, weight: .semibold))
                .foregroundStyle(Theme.Palette.accentText)
        } else {
            Text(verbatim: Self.initials(name))
                .font(.system(size: side * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.accentText)
        }
    }

    /// «Иван Петров» → «ИП»; one word gives one letter, no name gives none.
    nonisolated static func initials(_ name: String?) -> String {
        (name ?? "")
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
    }
}

#Preview {
    HStack {
        BrandAvatar(name: "Иван Петров")
        BrandAvatar(name: nil, systemImage: "building.2")
        BrandAvatar(name: "Мария", side: 64)
    }
    .padding()
}
