import PlayerzAPI
import SwiftUI
import UIKit

/// A sport's banner photo from the app's resources (SportArt), decoded once.
enum SportArtImage {
    @MainActor private static var cache: [String: UIImage] = [:]

    /// The picture for `sport`, or nil for a sport without one.
    @MainActor static func image(_ sport: String) -> UIImage? {
        guard let name = SportArt.resource(sport) else { return nil }
        if let cached = cache[name] { return cached }
        guard let path = Bundle.main.path(forResource: name, ofType: "webp"),
              let image = UIImage(contentsOfFile: path)
        else { return nil }
        cache[name] = image
        return image
    }
}

/// A sport's photo filling its frame under the ink scrims of the design draft
/// (owner 2026-11-13: "a bit of elegance"): darker on the leading side where
/// the words sit, and at the foot. Without a picture, the sport's drawn
/// surface. Decoration only: the sport's name is always beside it.
struct SportBackdrop: View {
    let sport: String
    /// How far the leading scrim reaches: strong behind a hero's headline,
    /// light where only a line of text sits on it.
    var scrim: Double = 0.86

    var body: some View {
        Color.clear
            .overlay {
                if let image = SportArtImage.image(sport) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    SportPitchView(sport: sport, rounded: false).scaleEffect(1.35)
                }
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Theme.Palette.ink.opacity(scrim), location: 0),
                        .init(color: Theme.Palette.ink.opacity(scrim * 0.6), location: 0.5),
                        .init(color: .clear, location: 0.95),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, Theme.Palette.ink.opacity(0.66)],
                    startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom
                )
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Every sport's photo in turn, a crossfade every `interval` seconds (owner
/// 2026-11-13: "the image on the home page needs to slideshow with all other
/// banners", "5s"). Still, on the first, when Reduce Motion is on.
struct SportSlideshow: View {
    let sports: [String]
    var interval: Double = 5

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !sports.isEmpty {
                SportBackdrop(sport: sports[index % sports.count])
                    .id(index)
                    .transition(.opacity)
            }
        }
        .task(id: reduceMotion) {
            guard !reduceMotion, sports.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                // The next photo decoded before it fades in, not during.
                _ = SportArtImage.image(sports[(index + 1) % sports.count])
                withAnimation(.easeInOut(duration: 0.9)) { index = (index + 1) % sports.count }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A short banner at the top of a sport's page (a place's hours): the photo,
/// a title and a line under it, on the ink scrim. As the draft's
/// `.club-banner`.
struct SportBanner<Trailing: View>: View {
    let sport: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.cardTitle)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.muted)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            trailing
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .bottomLeading)
        .background { SportBackdrop(sport: sport, scrim: 0.82) }
        .clipShape(.rect(cornerRadius: Theme.Radius.row))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Palette.photoEdge))
        // On a photo, so dark in both modes.
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }
}

extension SportBanner where Trailing == EmptyView {
    init(sport: String, title: String, subtitle: String? = nil) {
        self.init(sport: sport, title: title, subtitle: subtitle) { EmptyView() }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(["TENNIS", "PADEL", "FOOTBALL5", "CURLING"], id: \.self) { sport in
                SportBanner(sport: sport, title: "Корт 2", subtitle: "Открит корт") { Text(verbatim: "18° ☀︎") }
            }
        }
        .padding()
    }
    .brandPage()
}
