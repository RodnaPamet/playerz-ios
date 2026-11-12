import PlayerzAPI
import SwiftUI

/// A venue's or a club's cover: the club's own photo when the server has one
/// (#366), else a drawn band with a court on it. Never a stock picture: a
/// photo that is not the club's would say something untrue about it.
///
/// It fills whatever frame it is given and clips itself.
struct VenueCover: View {
    let photo: Components.Schemas.VenuePhoto?
    /// Any stable text of the club (its id): which way the drawn band leans.
    let seed: String
    /// The server's address, for a photo path without a host.
    let serverURL: String
    /// The width in pixels to ask for: 640 fills a list card, 1280 a screen's top.
    var pixelWidth = 640

    var body: some View {
        // The picture is an overlay: a filling image must not widen its card.
        drawn
            .overlay {
                if let photo, let url = Self.url(for: photo, pixelWidth: pixelWidth, serverURL: serverURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if let blur = Self.placeholder(photo.blurDataUrl) {
                            // The server's 16px preview, while the picture loads.
                            Image(uiImage: blur).resizable().scaledToFill().blur(radius: 14)
                        }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var drawn: some View {
        let lean = Self.lean(seed)
        return LinearGradient(
            colors: [Theme.Palette.headerInk, Theme.Palette.headerGlow],
            startPoint: lean.start, endPoint: lean.end
        )
        .overlay {
            RadialGradient(
                colors: [Theme.Palette.accentFill.opacity(0.55), .clear],
                center: lean.glow, startRadius: 0, endRadius: 220
            )
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "sportscourt")
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .foregroundStyle(Theme.Palette.onHeader.opacity(0.14))
                .rotationEffect(.degrees(lean.tilt))
                .padding(.vertical, Theme.Spacing.m)
                .padding(.trailing, Theme.Spacing.xl)
        }
    }

    // MARK: Pure parts

    struct Lean { let start: UnitPoint; let end: UnitPoint; let glow: UnitPoint; let tilt: Double }

    /// One of a few leans, the same for a club every time (`hashValue` is not:
    /// it changes with each launch).
    nonisolated static func lean(_ seed: String) -> Lean {
        let leans = [
            Lean(start: .topLeading, end: .bottomTrailing, glow: .topTrailing, tilt: -10),
            Lean(start: .bottomLeading, end: .topTrailing, glow: .bottomTrailing, tilt: 8),
            Lean(start: .top, end: .bottom, glow: .trailing, tilt: -4),
            Lean(start: .topTrailing, end: .bottomLeading, glow: .bottomLeading, tilt: 12),
        ]
        let sum = seed.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 1009 }
        return leans[sum % leans.count]
    }

    /// The narrowest rendition that still fills `pixelWidth`, else the widest.
    nonisolated static func url(
        for photo: Components.Schemas.VenuePhoto, pixelWidth: Int, serverURL: String
    ) -> URL? {
        let sorted = photo.variants.sorted { $0.width < $1.width }
        let pick = sorted.first { $0.width >= pixelWidth }?.url ?? sorted.last?.url ?? photo.url
        return mediaURL(pick, serverURL: serverURL)
    }

    /// `data:image/webp;base64,…` as a picture.
    nonisolated static func placeholder(_ dataURL: String?) -> UIImage? {
        guard let dataURL, let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
        else { return nil }
        return UIImage(data: data)
    }
}

/// A picture's address as the server gave it; a path without a host is on the
/// server the app is signed in to.
nonisolated func mediaURL(_ text: String, serverURL: String) -> URL? {
    guard let url = URL(string: text) else { return nil }
    if url.scheme != nil { return url }
    guard let base = URL(string: serverURL), base.scheme != nil else { return nil }
    return URL(string: text, relativeTo: base)?.absoluteURL
}

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
        .background(prominent ? Theme.Palette.accentFill : Theme.Palette.chipIdle, in: .capsule)
    }
}

/// What a venue's card and a venue's own screen say in chips, and how
/// VoiceOver hears it.
enum VenueFacts {
    /// «от 24,00 €». The summary carries no currency; every club is in euro
    /// (as the list has shown it since the first version).
    /// In the club's currency since the server names it (projectZ#667); EUR
    /// when it does not, as every club so far charges.
    static func price(fromCents cents: Int, currency: String? = nil) -> String {
        let money = (Decimal(cents) / 100).formatted(
            .currency(code: currency ?? "EUR").locale(Locale(identifier: "bg_BG"))
        )
        return String(format: String(localized: "venues.fromPrice"), money)
    }

    /// Nil with no reviews: the server's 0 means "none yet", not a bad score.
    static func rating(_ average: Double, count: Int) -> (shown: String, spoken: String)? {
        guard count > 0 else { return nil }
        let score = average.formatted(.number.precision(.fractionLength(1)))
        return ("\(score) (\(count))", String(localized: "venues.a11y.rating \(score) \(count)"))
    }

    static func sports(_ codes: [String]) -> [String] {
        codes.map(GameText.sport)
    }
}

/// Chips one after another, on as many lines as they need: a row of them
/// would cut the last one off at large text sizes.
struct ChipFlow: Layout {
    var spacing: CGFloat = Theme.Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = arrange(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, placed.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            // A chip wider than the line is given the line, and wraps its text.
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + lineHeight), frames)
    }
}
