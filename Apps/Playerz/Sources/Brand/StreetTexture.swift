import SwiftUI

/// A small step toward the street (owner 2026-11-13: "marginal improvements
/// toward graffiti, concrete and street art", the layout and colours as they
/// are): the page is smooth concrete, the header band is sprayed.
///
/// Seeded, so the grain is the same on every frame and every launch; faint,
/// so it never competes with text. Decoration only, hidden from VoiceOver.

/// A deterministic run of numbers in 0..<1 (a linear congruential generator):
/// texture that does not shimmer as views redraw.
struct TextureNoise {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

/// The page colour as smooth concrete: a fine grain, light and dark specks,
/// and a few soft stains where water ran.
struct ConcreteBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Theme.Palette.page
            .overlay {
                Canvas(rendersAsynchronously: true) { context, size in
                    let dark = scheme == .dark
                    var noise = TextureNoise(seed: 0xC0FFEE)
                    // Stains: wide, very soft blotches.
                    for _ in 0..<5 {
                        let x = noise.next() * size.width, y = noise.next() * size.height
                        let r = (0.25 + noise.next() * 0.35) * max(size.width, 320)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)),
                            with: .radialGradient(
                                Gradient(colors: [(dark ? Color.white : Color.black).opacity(dark ? 0.025 : 0.035), .clear]),
                                center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r
                            )
                        )
                    }
                    // Grain: one speck per ~90 points², dark and light.
                    let count = Int(size.width * size.height / 90)
                    for i in 0..<count {
                        let x = noise.next() * size.width, y = noise.next() * size.height
                        let d = 0.6 + noise.next() * 1.1
                        let light = i % 3 == 0
                        let colour: Color = dark
                            ? .white.opacity(light ? 0.06 : 0.035)
                            : (light ? Color.white.opacity(0.6) : Color.black.opacity(0.075))
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(colour))
                    }
                    // Pits: the odd small hole in the surface.
                    for _ in 0..<Int(size.width * size.height / 2600) {
                        let x = noise.next() * size.width, y = noise.next() * size.height
                        let d = 1.6 + noise.next() * 1.6
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d * 0.8)),
                            with: .color(Color.black.opacity(dark ? 0.35 : 0.09))
                        )
                    }
                }
            }
            .accessibilityHidden(true)
    }
}

/// Fine spray speckle and a soft overspray cloud over the header band.
struct SprayTexture: View {
    var body: some View {
        Canvas { context, size in
            var noise = TextureNoise(seed: 0x5A11)
            // The overspray: where the can lingered, trailing side.
            let cloud = CGPoint(x: size.width * 0.82, y: size.height * 0.35)
            let r = max(size.width, size.height) * 0.55
            context.fill(
                Path(ellipseIn: CGRect(x: cloud.x - r, y: cloud.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(
                    Gradient(colors: [Theme.Palette.accentFill.opacity(0.32), .clear]),
                    center: cloud, startRadius: 0, endRadius: r
                )
            )
            // The speckle: denser near the cloud, as a can sprays.
            for _ in 0..<Int(size.width * size.height / 70) {
                let x = noise.next() * size.width, y = noise.next() * size.height
                let near = 1 - min(1, hypot(x - cloud.x, y - cloud.y) / r)
                guard noise.next() < 0.35 + near * 0.65 else { continue }
                let d = 0.6 + noise.next() * 1.4
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                    with: .color(.white.opacity(0.05 + near * 0.08))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// A few runs of paint off the header band's lower edge, in the band's own
/// colours: ink on the leading side, the glow on the trailing.
struct SprayDrips: View {
    static let reach: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let drips: [(x: CGFloat, length: CGFloat, width: CGFloat)] = [
                (0.13, 0.55, 4), (0.36, 1.0, 5), (0.41, 0.4, 3), (0.71, 0.75, 4.5), (0.9, 0.35, 3),
            ]
            for drip in drips {
                let x = size.width * drip.x
                let length = size.height * drip.length
                var path = Path()
                path.move(to: CGPoint(x: x - drip.width, y: 0))
                path.addLine(to: CGPoint(x: x + drip.width, y: 0))
                path.addLine(to: CGPoint(x: x + drip.width / 2, y: length - drip.width / 2))
                path.addArc(center: CGPoint(x: x, y: length - drip.width / 2), radius: drip.width / 2,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                path.closeSubpath()
                let colour = drip.x < 0.5 ? Theme.Palette.headerInk : Theme.Palette.headerGlow
                context.fill(path, with: .color(colour))
            }
        }
        .frame(height: Self.reach)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
