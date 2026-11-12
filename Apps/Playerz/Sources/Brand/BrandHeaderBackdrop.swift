import SwiftUI

/// The header band's texture, drawn in code: ink fading to purple, faint
/// court-line rings on the trailing side, a diagonal hatch. Decoration only.
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

            var hatch = Path()
            var x = -size.height
            while x < size.width {
                hatch.move(to: CGPoint(x: x, y: size.height))
                hatch.addLine(to: CGPoint(x: x + size.height * 0.6, y: 0))
                x += 26
            }
            context.stroke(hatch, with: .color(.white.opacity(0.04)), lineWidth: 1)

            let centre = CGPoint(x: size.width * 0.88, y: size.height * 0.62)
            for ring in 0..<4 {
                let radius = size.height * (0.3 + 0.26 * Double(ring))
                let circle = Path(ellipseIn: CGRect(
                    x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2
                ))
                context.stroke(circle, with: .color(.white.opacity(0.07)), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    BrandHeaderBackdrop().frame(height: 140)
}
