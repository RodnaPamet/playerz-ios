import SwiftUI

/// «Начало» sketched in pencil, under a second (owner 2026-11-27).
///
/// Gold-to-rose lines trace the home screen's layout (the header, the hero
/// banner, the chips, a club card with the next one peeking in, a sport card,
/// the tab bar), each element a beat after the one before, while a pencil tip
/// rides the line being drawn. Then the sketch fades and the real screen,
/// loaded underneath all along, is there. Drawn with `Canvas`: no asset, no
/// library.
///
/// Once per cold launch, only when the app opens on «Начало», never with
/// Reduce Motion (`PlayerShell`). It takes no taps and VoiceOver skips it.
struct LaunchSketch: View {
    /// Played in this process already: a tab switch never replays it.
    @MainActor static var played = false

    let onDone: () -> Void

    @State private var start = Date.now

    /// Lines draw until here, then the sketch fades out over `fade`.
    static let drawEnd = 0.7
    static let fade = 0.25

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { gc, size in
                draw(&gc, size: size, t: t)
            }
            .background(Theme.Palette.page)
            .opacity(t < Self.drawEnd ? 1 : max(0, 1 - (t - Self.drawEnd) / Self.fade))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(Self.drawEnd + Self.fade))
            onDone()
        }
    }

    /// One element of the layout: its outline, when it starts, how long it takes.
    private struct Stroke {
        let path: Path
        let delay: Double
        let duration: Double
    }

    private func strokes(in size: CGSize) -> [Stroke] {
        let w = size.width, h = size.height
        let m = w * 0.05
        func rect(_ y: Double, _ height: Double, x: Double? = nil, width: Double? = nil, r: Double = 16) -> Path {
            Path(roundedRect: CGRect(x: x ?? m, y: h * y, width: width ?? (w - 2 * m), height: h * height),
                 cornerRadius: r)
        }
        func line(_ y: Double, from x0: Double, to x1: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: w * x0, y: h * y))
            p.addLine(to: CGPoint(x: w * x1, y: h * y))
            return p
        }
        var chips = Path()
        for i in 0..<4 {
            let x = m + Double(i) * (w * 0.22)
            chips.addRoundedRect(in: CGRect(x: x, y: h * 0.355, width: w * 0.19, height: h * 0.035),
                                 cornerSize: CGSize(width: 12, height: 12))
        }
        var bar = line(0.915, from: 0, to: 1)
        for i in 0..<4 {
            bar.addEllipse(in: CGRect(x: w * (0.14 + Double(i) * 0.24) - 6, y: h * 0.94, width: 12, height: 12))
        }
        var header = line(0.075, from: 0.05, to: 0.42)
        header.addEllipse(in: CGRect(x: w - m - 30, y: h * 0.06, width: 30, height: 30))
        var heroText = line(0.29, from: 0.1, to: 0.6)
        heroText.addPath(line(0.315, from: 0.1, to: 0.42))
        return [
            Stroke(path: header, delay: 0.00, duration: 0.18),
            Stroke(path: rect(0.11, 0.23), delay: 0.04, duration: 0.30),
            Stroke(path: heroText, delay: 0.16, duration: 0.18),
            Stroke(path: chips, delay: 0.20, duration: 0.24),
            Stroke(path: line(0.43, from: 0.05, to: 0.3), delay: 0.28, duration: 0.12),
            Stroke(path: rect(0.455, 0.2, width: w * 0.82), delay: 0.30, duration: 0.28),
            Stroke(path: rect(0.455, 0.2, x: w * 0.89, width: w * 0.2), delay: 0.38, duration: 0.18),
            Stroke(path: line(0.695, from: 0.05, to: 0.28), delay: 0.40, duration: 0.12),
            Stroke(path: rect(0.72, 0.15, width: w * 0.82), delay: 0.42, duration: 0.24),
            Stroke(path: bar, delay: 0.46, duration: 0.22),
        ]
    }

    private func draw(_ gc: inout GraphicsContext, size: CGSize, t: Double) {
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Theme.Palette.accentFill, Theme.Palette.accentFillEnd]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
        )
        let style = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        var tip: CGPoint?
        for stroke in strokes(in: size) {
            let p = min(1, max(0, (t - stroke.delay) / stroke.duration))
            guard p > 0 else { continue }
            let drawn = stroke.path.trimmedPath(from: 0, to: p)
            gc.stroke(drawn, with: shading, style: style)
            // The pencil is wherever the latest line still being drawn ends.
            if p < 1, let end = drawn.currentPoint { tip = end }
        }
        if let tip, t < Self.drawEnd {
            var pencil = gc.resolve(Image(systemName: "pencil"))
            pencil.shading = .color(Theme.Palette.accentText)
            // The tip of the symbol is its lower left corner: put it on the line.
            gc.draw(pencil, in: CGRect(x: tip.x, y: tip.y - 22, width: 22, height: 22))
        }
    }
}
