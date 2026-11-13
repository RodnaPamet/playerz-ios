import PlayerzAPI
import SwiftUI

/// Each sport's playing surface from above, in its real colours and
/// markings (owner 2026-11-13: "different pitches image for each sport"):
/// the court picker's tiles, a game's court and a club's drawn cover.
///
/// Drawn in a landscape box, the length across. Proportions follow each
/// sport's rules closely enough to be recognised (a tennis court's singles
/// lines, a basketball key, a handball D), not to be measured. A sport added
/// after this build gets a plain court.
struct SportPitchView: View {
    let sport: String
    /// Rounded as a tile; a cover fills its card square-edged.
    var rounded = true

    var body: some View {
        Canvas { context, size in
            SportPitch.paint(sport, in: CGRect(origin: .zero, size: size), &context)
        }
        .clipShape(.rect(cornerRadius: rounded ? Theme.Radius.tile : 0))
        .accessibilityHidden(true)
    }
}

enum SportPitch {
    // MARK: Colours

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static let white = Color.white.opacity(0.92)
    private static let sand = (hex(0xE6C886), hex(0xD4AE62))
    private static let grass = (hex(0x3E9B4F), hex(0x2F7F3F))

    // MARK: Painting

    static func paint(_ sport: String, in rect: CGRect, _ c: inout GraphicsContext) {
        let lw = max(1, min(rect.width, rect.height) * 0.018)
        switch sport {
        case "TENNIS": tennis(rect, &c, lw)
        case "PADEL": padel(rect, &c, lw)
        case "BADMINTON": badminton(rect, &c, lw)
        case "TABLE_TENNIS": tableTennis(rect, &c, lw)
        case "BEACH_TENNIS": beach(rect, &c, lw, attack: false)
        case "PICKLEBALL": pickleball(rect, &c, lw)
        case "SQUASH": squash(rect, &c, lw)
        case "FOOTBALL": football(rect, &c, lw)
        case "FOOTBALL5": futsal(rect, &c, lw)
        case "BASKETBALL": basketball(rect, &c, lw)
        case "VOLLEYBALL": volleyball(rect, &c, lw)
        case "BEACH_VOLLEYBALL": beach(rect, &c, lw, attack: true)
        case "HANDBALL": handball(rect, &c, lw)
        case "CHESS": chess(rect, &c, lw)
        case "ESPORTS": esports(rect, &c, lw)
        case "KARTING": karting(rect, &c, lw)
        case "RUNNING": running(rect, &c, lw)
        case "CYCLING": cycling(rect, &c, lw)
        default: plain(rect, &c, lw)
        }
    }

    // MARK: Helpers

    private static func fill(_ rect: CGRect, _ c: inout GraphicsContext, _ colours: (Color, Color)) {
        c.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [colours.0, colours.1]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
    }

    /// The field inside the run-off, keeping `aspect` (length / width).
    private static func field(_ rect: CGRect, aspect: CGFloat, margin: CGFloat = 0.1) -> CGRect {
        let inner = rect.insetBy(dx: rect.width * margin, dy: rect.height * margin)
        var w = inner.width, h = inner.width / aspect
        if h > inner.height { h = inner.height; w = h * aspect }
        return CGRect(x: inner.midX - w / 2, y: inner.midY - h / 2, width: w, height: h)
    }

    private static func line(_ a: CGPoint, _ b: CGPoint, _ c: inout GraphicsContext, _ lw: CGFloat, _ colour: Color = white, dash: [CGFloat] = []) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        c.stroke(p, with: .color(colour), style: StrokeStyle(lineWidth: lw, lineCap: .round, dash: dash))
    }

    private static func box(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat, _ colour: Color = white) {
        c.stroke(Path(r), with: .color(colour), lineWidth: lw)
    }

    /// The net across the middle, a little heavier than the lines.
    private static func net(_ f: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat, over: CGFloat = 0.06) {
        let extra = f.height * over
        line(CGPoint(x: f.midX, y: f.minY - extra), CGPoint(x: f.midX, y: f.maxY + extra), &c, lw * 1.8, Color.white)
    }

    private static func vertical(_ f: CGRect, _ x: CGFloat, _ c: inout GraphicsContext, _ lw: CGFloat, from y0: CGFloat? = nil, to y1: CGFloat? = nil, colour: Color = white, dash: [CGFloat] = []) {
        line(CGPoint(x: x, y: y0 ?? f.minY), CGPoint(x: x, y: y1 ?? f.maxY), &c, lw, colour, dash: dash)
    }

    private static func horizontal(_ f: CGRect, _ y: CGFloat, _ c: inout GraphicsContext, _ lw: CGFloat, from x0: CGFloat? = nil, to x1: CGFloat? = nil, colour: Color = white) {
        line(CGPoint(x: x0 ?? f.minX, y: y), CGPoint(x: x1 ?? f.maxX, y: y), &c, lw, colour)
    }

    // MARK: Racket and net sports

    private static func tennis(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0xC9653F), hex(0xA84E2F)))
        let f = field(r, aspect: 23.77 / 10.97, margin: 0.12)
        box(f, &c, lw)
        let alley = f.height * 0.125
        horizontal(f, f.minY + alley, &c, lw)
        horizontal(f, f.maxY - alley, &c, lw)
        let service = f.width / 2 * (6.40 / 11.885)
        vertical(f, f.midX - service, &c, lw, from: f.minY + alley, to: f.maxY - alley)
        vertical(f, f.midX + service, &c, lw, from: f.minY + alley, to: f.maxY - alley)
        horizontal(f, f.midY, &c, lw, from: f.midX - service, to: f.midX + service)
        horizontal(f, f.midY, &c, lw, from: f.minX, to: f.minX + f.width * 0.02)
        horizontal(f, f.midY, &c, lw, from: f.maxX - f.width * 0.02, to: f.maxX)
        net(f, &c, lw)
    }

    private static func padel(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x2D72D2), hex(0x1E55A6)))
        let f = field(r, aspect: 2, margin: 0.1)
        // The glass walls round the court.
        c.stroke(Path(roundedRect: f.insetBy(dx: -lw * 2.5, dy: -lw * 2.5), cornerRadius: lw * 2),
                 with: .color(Color.white.opacity(0.35)), lineWidth: lw * 3)
        box(f, &c, lw)
        let service = f.width / 2 * (6.95 / 10)
        vertical(f, f.midX - service, &c, lw)
        vertical(f, f.midX + service, &c, lw)
        horizontal(f, f.midY, &c, lw, from: f.midX - service, to: f.midX + service)
        net(f, &c, lw, over: 0)
    }

    private static func badminton(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x2F8F5B), hex(0x22704A)))
        let f = field(r, aspect: 13.4 / 6.1, margin: 0.12)
        box(f, &c, lw)
        let side = f.height * 0.075
        horizontal(f, f.minY + side, &c, lw)
        horizontal(f, f.maxY - side, &c, lw)
        let short = f.width / 2 * (1.98 / 6.7), long = f.width / 2 * (0.76 / 6.7)
        vertical(f, f.midX - short, &c, lw)
        vertical(f, f.midX + short, &c, lw)
        vertical(f, f.minX + long, &c, lw)
        vertical(f, f.maxX - long, &c, lw)
        horizontal(f, f.midY, &c, lw, from: f.minX, to: f.midX - short)
        horizontal(f, f.midY, &c, lw, from: f.midX + short, to: f.maxX)
        net(f, &c, lw)
    }

    private static func pickleball(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x2E7FA8), hex(0x22668A)))
        let f = field(r, aspect: 13.41 / 6.1, margin: 0.12)
        c.fill(Path(f), with: .color(hex(0x3FA37A)))
        // The non-volley zone, «the kitchen», each side of the net.
        let kitchen = f.width / 2 * (2.13 / 6.705)
        c.fill(Path(CGRect(x: f.midX - kitchen, y: f.minY, width: kitchen * 2, height: f.height)), with: .color(hex(0x2C8A63)))
        box(f, &c, lw)
        vertical(f, f.midX - kitchen, &c, lw)
        vertical(f, f.midX + kitchen, &c, lw)
        horizontal(f, f.midY, &c, lw, from: f.minX, to: f.midX - kitchen)
        horizontal(f, f.midY, &c, lw, from: f.midX + kitchen, to: f.maxX)
        net(f, &c, lw)
    }

    private static func squash(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0xDCA56A), hex(0xC4874B)))
        let red = hex(0xC8282E)
        let f = field(r, aspect: 9.75 / 6.4, margin: 0.1)
        // The front wall on the left, then the floor's lines in red.
        c.fill(Path(CGRect(x: f.minX - lw * 4, y: f.minY, width: lw * 4, height: f.height)), with: .color(Color.white.opacity(0.7)))
        box(f, &c, lw, red)
        let short = f.minX + f.width * (5.44 / 9.75)
        vertical(f, short, &c, lw, colour: red)
        horizontal(f, f.midY, &c, lw, from: short, to: f.maxX, colour: red)
        let s = f.height * 0.25
        box(CGRect(x: short, y: f.minY, width: s, height: s), &c, lw, red)
        box(CGRect(x: short, y: f.maxY - s, width: s, height: s), &c, lw, red)
    }

    private static func tableTennis(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x5B6170), hex(0x454A57)))
        let f = field(r, aspect: 2.74 / 1.525, margin: 0.14)
        c.fill(Path(roundedRect: f, cornerRadius: lw), with: .color(hex(0x1D4E9C)))
        box(f, &c, lw * 1.4)
        horizontal(f, f.midY, &c, lw * 0.7)
        net(f, &c, lw, over: 0.08)
    }

    private static func beach(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat, attack: Bool) {
        fill(r, &c, sand)
        let rope = hex(0x1F4E9C)
        let f = field(r, aspect: attack ? 2 : 16 / 8, margin: 0.12)
        box(f, &c, lw * 1.3, rope)
        if !attack {
            // Beach tennis: the service line each side.
            vertical(f, f.minX + f.width * 0.12, &c, lw, colour: rope)
            vertical(f, f.maxX - f.width * 0.12, &c, lw, colour: rope)
        }
        net(f, &c, lw)
    }

    private static func volleyball(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x3264AE), hex(0x244D8A)))
        let f = field(r, aspect: 2, margin: 0.14)
        c.fill(Path(f), with: .color(hex(0xE0813F)))
        box(f, &c, lw)
        let attack = f.width / 2 / 3
        vertical(f, f.midX - attack, &c, lw)
        vertical(f, f.midX + attack, &c, lw)
        net(f, &c, lw)
    }

    // MARK: Pitches and halls

    private static func football(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, grass)
        // Mowing stripes.
        let stripes = 10
        for i in stride(from: 0, to: stripes, by: 2) {
            let w = r.width / CGFloat(stripes)
            c.fill(Path(CGRect(x: r.minX + CGFloat(i) * w, y: r.minY, width: w, height: r.height)), with: .color(Color.white.opacity(0.06)))
        }
        let f = field(r, aspect: 105.0 / 68, margin: 0.09)
        box(f, &c, lw)
        vertical(f, f.midX, &c, lw)
        let circle = f.height * (9.15 / 68)
        c.stroke(Path(ellipseIn: CGRect(x: f.midX - circle, y: f.midY - circle, width: circle * 2, height: circle * 2)), with: .color(white), lineWidth: lw)
        for left in [true, false] {
            let depth = f.width * (16.5 / 105), wide = f.height * (40.3 / 68)
            let small = f.width * (5.5 / 105), smallWide = f.height * (18.3 / 68)
            let x = left ? f.minX : f.maxX - depth
            box(CGRect(x: x, y: f.midY - wide / 2, width: depth, height: wide), &c, lw)
            box(CGRect(x: left ? f.minX : f.maxX - small, y: f.midY - smallWide / 2, width: small, height: smallWide), &c, lw)
            let goal = f.height * (7.32 / 68), gx = left ? f.minX - lw * 3 : f.maxX
            box(CGRect(x: gx, y: f.midY - goal / 2, width: lw * 3, height: goal), &c, lw)
        }
    }

    private static func futsal(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x2E8A57), hex(0x226B43)))
        let f = field(r, aspect: 40.0 / 20, margin: 0.1)
        box(f, &c, lw)
        vertical(f, f.midX, &c, lw)
        let circle = f.height * 0.15
        c.stroke(Path(ellipseIn: CGRect(x: f.midX - circle, y: f.midY - circle, width: circle * 2, height: circle * 2)), with: .color(white), lineWidth: lw)
        let radius = f.width * (6 / 40)
        for left in [true, false] {
            var arc = Path()
            arc.addArc(center: CGPoint(x: left ? f.minX : f.maxX, y: f.midY), radius: radius,
                       startAngle: .degrees(left ? -90 : 90), endAngle: .degrees(left ? 90 : 270), clockwise: false)
            c.stroke(arc, with: .color(white), lineWidth: lw)
            let goal = f.height * 0.15, gx = left ? f.minX - lw * 3 : f.maxX
            box(CGRect(x: gx, y: f.midY - goal / 2, width: lw * 3, height: goal), &c, lw)
        }
    }

    private static func basketball(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0xD6914E), hex(0xBA7437)))
        let f = field(r, aspect: 28.0 / 15, margin: 0.1)
        box(f, &c, lw)
        vertical(f, f.midX, &c, lw)
        let circle = f.height * (1.8 / 15)
        c.stroke(Path(ellipseIn: CGRect(x: f.midX - circle, y: f.midY - circle, width: circle * 2, height: circle * 2)), with: .color(white), lineWidth: lw)
        for left in [true, false] {
            let depth = f.width * (5.8 / 28), wide = f.height * (4.9 / 15)
            let key = CGRect(x: left ? f.minX : f.maxX - depth, y: f.midY - wide / 2, width: depth, height: wide)
            c.fill(Path(key), with: .color(hex(0xA85A2A)))
            box(key, &c, lw)
            // The three-point arc, from the basket.
            let basket = CGPoint(x: left ? f.minX + f.width * (1.575 / 28) : f.maxX - f.width * (1.575 / 28), y: f.midY)
            var arc = Path()
            arc.addArc(center: basket, radius: f.height * (6.75 / 15), startAngle: .degrees(left ? -78 : 102), endAngle: .degrees(left ? 78 : 258), clockwise: false)
            c.stroke(arc, with: .color(white), lineWidth: lw)
            c.stroke(Path(ellipseIn: CGRect(x: basket.x - lw * 2, y: basket.y - lw * 2, width: lw * 4, height: lw * 4)), with: .color(hex(0xFF6A2B)), lineWidth: lw)
        }
    }

    private static func handball(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x2E6FB8), hex(0x235898)))
        let f = field(r, aspect: 2, margin: 0.1)
        box(f, &c, lw)
        vertical(f, f.midX, &c, lw)
        for left in [true, false] {
            let x = left ? f.minX : f.maxX
            // The 6 m goal area, filled, and the 9 m line dashed.
            for (radius, dashed) in [(f.width * (6 / 40), false), (f.width * (9 / 40), true)] {
                var d = Path()
                d.addArc(center: CGPoint(x: x, y: f.midY), radius: radius,
                         startAngle: .degrees(left ? -90 : 90), endAngle: .degrees(left ? 90 : 270), clockwise: false)
                if !dashed {
                    c.fill(d, with: .color(hex(0xE8954A)))
                }
                c.stroke(d, with: .color(white), style: StrokeStyle(lineWidth: lw, dash: dashed ? [lw * 3, lw * 3] : []))
            }
            let goal = f.height * (3 / 20), gx = left ? f.minX - lw * 3 : f.maxX
            box(CGRect(x: gx, y: f.midY - goal / 2, width: lw * 3, height: goal), &c, lw)
        }
    }

    // MARK: Boards, screens and tracks

    private static func chess(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x5A3A24), hex(0x3F2817)))
        let side = min(r.width, r.height) * 0.82
        let board = CGRect(x: r.midX - side / 2, y: r.midY - side / 2, width: side, height: side)
        let cell = side / 8
        for row in 0..<8 {
            for col in 0..<8 {
                let dark = (row + col) % 2 == 1
                c.fill(Path(CGRect(x: board.minX + CGFloat(col) * cell, y: board.minY + CGFloat(row) * cell, width: cell, height: cell)),
                       with: .color(dark ? hex(0x8B5A3C) : hex(0xEED7B5)))
            }
        }
        box(board, &c, lw, hex(0x2A1A0E))
    }

    private static func esports(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0x1A1238), hex(0x0E0A22)))
        let colours = [hex(0x39E6FF), hex(0xFF3FD2), hex(0x8CFF5A)]
        let cols = 3, rows = 2
        let area = r.insetBy(dx: r.width * 0.1, dy: r.height * 0.16)
        let w = area.width / CGFloat(cols), h = area.height / CGFloat(rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let screen = CGRect(x: area.minX + CGFloat(col) * w, y: area.minY + CGFloat(row) * h, width: w, height: h).insetBy(dx: w * 0.1, dy: h * 0.14)
                let colour = colours[(row * cols + col) % colours.count]
                c.fill(Path(roundedRect: screen, cornerRadius: lw * 1.5), with: .color(colour.opacity(0.18)))
                c.stroke(Path(roundedRect: screen, cornerRadius: lw * 1.5), with: .color(colour), lineWidth: lw)
            }
        }
    }

    private static func karting(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, grass)
        let a = r.insetBy(dx: r.width * 0.12, dy: r.height * 0.2)
        var track = Path()
        track.move(to: CGPoint(x: a.minX + a.width * 0.2, y: a.maxY))
        track.addCurve(to: CGPoint(x: a.minX, y: a.midY), control1: CGPoint(x: a.minX, y: a.maxY), control2: CGPoint(x: a.minX, y: a.maxY))
        track.addCurve(to: CGPoint(x: a.minX + a.width * 0.35, y: a.minY), control1: CGPoint(x: a.minX, y: a.minY), control2: CGPoint(x: a.minX + a.width * 0.2, y: a.minY))
        track.addCurve(to: CGPoint(x: a.minX + a.width * 0.6, y: a.midY), control1: CGPoint(x: a.minX + a.width * 0.5, y: a.minY), control2: CGPoint(x: a.minX + a.width * 0.45, y: a.midY))
        track.addCurve(to: CGPoint(x: a.maxX, y: a.minY + a.height * 0.2), control1: CGPoint(x: a.minX + a.width * 0.8, y: a.midY), control2: CGPoint(x: a.maxX, y: a.minY))
        track.addCurve(to: CGPoint(x: a.maxX - a.width * 0.15, y: a.maxY), control1: CGPoint(x: a.maxX, y: a.maxY), control2: CGPoint(x: a.maxX, y: a.maxY))
        track.closeSubpath()
        let width = min(r.width, r.height) * 0.13
        c.stroke(track, with: .color(hex(0xD92D3A)), style: StrokeStyle(lineWidth: width + lw * 2.4, lineJoin: .round))
        c.stroke(track, with: .color(.white), style: StrokeStyle(lineWidth: width + lw * 2.4, lineJoin: .round, dash: [width * 0.5, width * 0.5]))
        c.stroke(track, with: .color(hex(0x48484F)), style: StrokeStyle(lineWidth: width, lineJoin: .round))
        // The start line, chequered.
        let start = CGPoint(x: a.midX - a.width * 0.05, y: a.maxY)
        for i in 0..<4 {
            let s = width / 4
            c.fill(Path(CGRect(x: start.x, y: start.y - width / 2 + CGFloat(i) * s, width: s, height: s)), with: .color(i % 2 == 0 ? .white : .black))
        }
    }

    private static func running(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (hex(0xB8492F), hex(0x9C3A24)))
        let outer = r.insetBy(dx: r.width * 0.07, dy: r.height * 0.1)
        let lanes = 4
        let laneWidth = outer.height * 0.07
        for i in 0...lanes {
            let lane = outer.insetBy(dx: CGFloat(i) * laneWidth, dy: CGFloat(i) * laneWidth)
            c.stroke(Path(roundedRect: lane, cornerRadius: lane.height / 2), with: .color(white), lineWidth: lw * 0.8)
        }
        let infield = outer.insetBy(dx: CGFloat(lanes) * laneWidth + lw, dy: CGFloat(lanes) * laneWidth + lw)
        c.fill(Path(roundedRect: infield, cornerRadius: infield.height / 2), with: .color(grass.0))
    }

    private static func cycling(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, grass)
        var road = Path()
        road.move(to: CGPoint(x: r.minX - 10, y: r.maxY - r.height * 0.25))
        road.addCurve(to: CGPoint(x: r.maxX + 10, y: r.minY + r.height * 0.25),
                      control1: CGPoint(x: r.midX - r.width * 0.1, y: r.maxY + r.height * 0.2),
                      control2: CGPoint(x: r.midX + r.width * 0.1, y: r.minY - r.height * 0.2))
        let width = r.height * 0.3
        c.stroke(road, with: .color(hex(0x55555E)), style: StrokeStyle(lineWidth: width, lineCap: .butt))
        c.stroke(road, with: .color(white), style: StrokeStyle(lineWidth: lw, dash: [lw * 4, lw * 4]))
    }

    private static func plain(_ r: CGRect, _ c: inout GraphicsContext, _ lw: CGFloat) {
        fill(r, &c, (Theme.Palette.headerGlow, Theme.Palette.controlOn))
        let f = field(r, aspect: 2, margin: 0.12)
        box(f, &c, lw)
        vertical(f, f.midX, &c, lw)
    }
}

#if DEBUG
/// Every sport's surface, for a look at them together (`PLAYERZ_PITCHES=1`).
struct SportPitchGallery: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Sports.known, id: \.self) { sport in
                    VStack(alignment: .leading, spacing: 4) {
                        SportPitchView(sport: sport).frame(height: 90)
                        Text(GameText.sport(sport)).font(.caption.weight(.semibold))
                    }
                }
            }
            .padding()
        }
        .defaultScrollAnchor(DebugLaunch.scrollEnd ? .bottom : .top)
        .background(Theme.Palette.page)
    }
}
#endif
