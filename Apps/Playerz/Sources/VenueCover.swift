import PlayerzAPI
import SwiftUI

/// A venue's or a club's cover: the club's own photo when the server has one
/// (#366), else its sport's banner photo (SportArt, owner 2026-11-13), else a
/// drawn band. The sport's photo is category art, never passed off as the
/// club's: it is decoration, and the club's own photo always replaces it.
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
    /// The club's sport: without a photo, its banner photo is the cover.
    var sport: String?

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

    @ViewBuilder private var drawn: some View {
        if let sport, !sport.isEmpty {
            pitch(sport)
        } else {
            band
        }
    }

    /// The sport's banner photo, darker at the foot where the club's tile
    /// sits on it; the drawn surface for a sport without one.
    private func pitch(_ sport: String) -> some View {
        SportBackdrop(sport: sport, scrim: 0.25)
    }

    private var band: some View {
        let lean = Self.lean(seed)
        return LinearGradient(
            colors: [Theme.Palette.headerInk, Theme.Palette.headerGlow],
            startPoint: lean.start, endPoint: lean.end
        )
        .overlay {
            RadialGradient(
                colors: [Theme.Palette.accentText.opacity(0.4), .clear],
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
