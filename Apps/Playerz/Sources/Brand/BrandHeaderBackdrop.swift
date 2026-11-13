import SwiftUI

/// The header band's texture, drawn in code: ink fading to purple, and
/// slanted speed lines on the trailing side. Decoration only.
struct BrandHeaderBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Theme.Palette.headerInk, Theme.Palette.headerInk, Theme.Palette.headerGlow]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            // Speed lines on the trailing side, slanted as the italic
            // headlines are (owner 2026-11-13: "more sports feeling").
            let slant = size.height * 0.45
            let stripes: [(x: CGFloat, width: CGFloat, alpha: Double)] = [
                (0.58, 3, 0.10), (0.64, 10, 0.16), (0.72, 4, 0.12), (0.78, 22, 0.20), (0.88, 6, 0.14), (0.94, 14, 0.18),
            ]
            for stripe in stripes {
                let x = size.width * stripe.x
                var band = Path()
                band.move(to: CGPoint(x: x + slant, y: 0))
                band.addLine(to: CGPoint(x: x + slant + stripe.width, y: 0))
                band.addLine(to: CGPoint(x: x + stripe.width, y: size.height))
                band.addLine(to: CGPoint(x: x, y: size.height))
                band.closeSubpath()
                context.fill(band, with: .linearGradient(
                    Gradient(colors: [Theme.Palette.accentFill.opacity(stripe.alpha * 1.6), .white.opacity(stripe.alpha * 0.4)]),
                    startPoint: CGPoint(x: x, y: size.height), endPoint: CGPoint(x: x + slant, y: 0)
                ))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    BrandHeaderBackdrop().frame(height: 140)
}
