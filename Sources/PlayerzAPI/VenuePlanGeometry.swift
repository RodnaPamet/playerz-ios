import CoreGraphics
import Foundation

/// The venue plan's drawing (#25, the web's `plan-geometry.ts`), as plain
/// numbers: nothing here touches a view, so all of it is tested without one.
/// Every shape is in METRES in the venue's frame: x east, y north, from the
/// venue's point. The web draws from the same functions, so a court looks the
/// same on both.
public enum VenuePlanGeometry {
    public typealias Point = SIMD2<Double>

    /// The points of a server outline (`[[x, y], …]`); nil when one is not a pair.
    public static func points(_ outline: [[Double]]) -> [Point]? {
        var out: [Point] = []
        for p in outline {
            guard p.count == 2, p[0].isFinite, p[1].isFinite else { return nil }
            out.append(Point(p[0], p[1]))
        }
        return out.count >= 3 ? out : nil
    }

    // MARK: - A court's frame

    /// Where a court lies: its centre, the direction of its long side, its size.
    public struct Frame: Equatable, Sendable {
        public var center: Point
        /// Radians from east to the long side, in 0..<π.
        public var angle: Double
        public var length: Double
        public var width: Double
    }

    /// The smallest rectangle around a court's outline, its long side as the
    /// length. One side of that rectangle lies along an edge of the convex
    /// hull, so every hull edge is tried: a court has a handful of points.
    public static func frame(of points: [Point]) -> Frame {
        let hull = convexHull(points)
        var best: Frame?
        var bestArea = Double.infinity
        for i in hull.indices {
            let a = hull[i]
            let b = hull[(i + 1) % hull.count]
            let theta = atan2(b.y - a.y, b.x - a.x)
            let (c, s) = (cos(theta), sin(theta))
            var (minU, maxU, minV, maxV) = (Double.infinity, -Double.infinity, Double.infinity, -Double.infinity)
            for p in hull {
                let u = p.x * c + p.y * s
                let v = -p.x * s + p.y * c
                minU = min(minU, u)
                maxU = max(maxU, u)
                minV = min(minV, v)
                maxV = max(maxV, v)
            }
            let area = (maxU - minU) * (maxV - minV)
            guard area < bestArea - 1e-9 else { continue }
            bestArea = area
            let (u, v) = ((minU + maxU) / 2, (minV + maxV) / 2)
            let along = maxU - minU >= maxV - minV
            best = Frame(
                center: Point(u * c - v * s, u * s + v * c),
                angle: folded(along ? theta : theta + .pi / 2),
                length: along ? maxU - minU : maxV - minV,
                width: along ? maxV - minV : maxU - minU
            )
        }
        return best ?? Frame(center: .zero, angle: 0, length: 0, width: 0)
    }

    /// An angle folded into 0..<π: a court's long side has no front and back.
    private static func folded(_ a: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: .pi)
        return r < 0 ? r + .pi : r
    }

    /// Andrew's monotone chain, counter-clockwise, without collinear points.
    private static func convexHull(_ points: [Point]) -> [Point] {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard sorted.count >= 3 else { return sorted }
        func cross(_ o: Point, _ a: Point, _ b: Point) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [Point] = []
        for p in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [Point] = []
        for p in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    // MARK: - Markings

    /// One stroke of a court's lines, in metres from its centre: x along its
    /// length, y across. A net and a wall are drawn heavier than a line.
    public struct Mark: Equatable, Sendable {
        public enum Stroke: Sendable { case line, net, wall }
        public var points: [Point]
        public var stroke: Stroke
    }

    /// A sport's lines at its standard size.
    public struct Markings: Sendable {
        public var length: Double
        public var width: Double
        public var marks: [Mark]
    }

    private static func line(_ points: [Point], _ stroke: Mark.Stroke = .line) -> Mark {
        Mark(points: points, stroke: stroke)
    }

    private static func box(_ l: Double, _ w: Double) -> Mark {
        line([Point(-l / 2, -w / 2), Point(l / 2, -w / 2), Point(l / 2, w / 2), Point(-l / 2, w / 2), Point(-l / 2, -w / 2)])
    }

    private static func arc(_ at: Point, _ r: Double, _ from: Double, _ to: Double, steps: Int = 24) -> Mark {
        line((0...steps).map { i in
            let a = from + (to - from) * Double(i) / Double(steps)
            return Point(at.x + r * cos(a), at.y + r * sin(a))
        })
    }

    private static func net(_ w: Double, overhang: Double = 0) -> Mark {
        line([Point(0, -w / 2 - overhang), Point(0, w / 2 + overhang)], .net)
    }

    /// Across the court at `x`.
    private static func across(_ x: Double, _ w: Double) -> Mark {
        line([Point(x, -w / 2), Point(x, w / 2)])
    }

    /// Handball's and futsal's goal area: quarter circles from the posts, joined.
    private static func goalArea(half: Double, r: Double, post: Double) -> [Mark] {
        var marks: [Mark] = []
        for s in [1.0, -1.0] {
            let x: Double = s * half
            // At the +x end the arcs open toward the middle; at the other they mirror.
            let upper: (Double, Double) = s > 0 ? (Double.pi / 2, Double.pi) : (0, Double.pi / 2)
            let lower: (Double, Double) = s > 0 ? (Double.pi, 3 * Double.pi / 2) : (-Double.pi / 2, 0)
            let inner: Double = x - s * r
            marks.append(arc(Point(x, post), r, upper.0, upper.1, steps: 12))
            marks.append(arc(Point(x, -post), r, lower.0, lower.1, steps: 12))
            marks.append(line([Point(inner, -post), Point(inner, post)]))
        }
        return marks
    }

    /// A rectangle's outline, open toward -x or +x: the three sides away from `x`.
    private static func endBox(at x: Double, depth: Double, width: Double, toward s: Double) -> Mark {
        let inner: Double = x - s * depth
        return line([Point(x, -width / 2), Point(inner, -width / 2), Point(inner, width / 2), Point(x, width / 2)])
    }

    /// Each sport's lines at the federations' sizes; nil draws the outline alone.
    public static func markings(for sport: String) -> Markings? {
        switch sport {
        case "TENNIS": return tennis()
        case "PADEL": return padel()
        case "BADMINTON": return badminton()
        case "PICKLEBALL": return pickleball()
        case "BEACH_TENNIS": return Markings(length: 16, width: 8, marks: [box(16, 8), net(8)])
        case "BEACH_VOLLEYBALL": return Markings(length: 16, width: 8, marks: [box(16, 8), net(8, overhang: 0.5)])
        case "VOLLEYBALL": return volleyball()
        case "TABLE_TENNIS": return tableTennis()
        case "SQUASH": return squash()
        case "BASKETBALL": return basketball()
        case "HANDBALL": return goalCourt(centreCircle: nil)
        case "FOOTBALL5": return goalCourt(centreCircle: 3)
        case "FOOTBALL": return football()
        default: return nil
        }
    }

    private static func tennis() -> Markings {
        let (l, w, singles, service): (Double, Double, Double, Double) = (23.77, 10.97, 8.23, 6.4)
        var marks: [Mark] = [box(l, w)]
        for s in [1.0, -1.0] {
            marks.append(line([Point(-l / 2, s * singles / 2), Point(l / 2, s * singles / 2)]))
            marks.append(line([Point(s * service, -singles / 2), Point(s * service, singles / 2)]))
        }
        marks.append(line([Point(-service, 0), Point(service, 0)]))
        marks.append(net(w, overhang: 0.914))
        return Markings(length: l, width: w, marks: marks)
    }

    private static func padel() -> Markings {
        let (l, w, service, glass): (Double, Double, Double, Double) = (20, 10, 6.95, 4)
        var marks: [Mark] = [box(l, w)]
        for s in [1.0, -1.0] {
            marks.append(across(s * service, w))
            // The glass: the back wall, and four metres of each side wall.
            let back: Double = s * l / 2
            let edge: Double = s * (l / 2 - glass)
            marks.append(line([Point(edge, -w / 2), Point(back, -w / 2), Point(back, w / 2), Point(edge, w / 2)], .wall))
        }
        marks.append(line([Point(-service, 0), Point(service, 0)]))
        marks.append(net(w))
        return Markings(length: l, width: w, marks: marks)
    }

    private static func badminton() -> Markings {
        let (l, w, singles, short, long): (Double, Double, Double, Double, Double) = (13.4, 6.1, 5.18, 1.98, 0.76)
        var marks: [Mark] = [box(l, w)]
        for s in [1.0, -1.0] {
            marks.append(line([Point(-l / 2, s * singles / 2), Point(l / 2, s * singles / 2)]))
            marks.append(across(s * short, w))
            marks.append(across(s * (l / 2 - long), w))
            marks.append(line([Point(s * short, 0), Point(s * l / 2, 0)]))
        }
        marks.append(net(w))
        return Markings(length: l, width: w, marks: marks)
    }

    private static func pickleball() -> Markings {
        let (l, w, kitchen): (Double, Double, Double) = (13.41, 6.1, 2.13)
        var marks: [Mark] = [box(l, w)]
        for s in [1.0, -1.0] {
            marks.append(across(s * kitchen, w))
            marks.append(line([Point(s * kitchen, 0), Point(s * l / 2, 0)]))
        }
        marks.append(net(w))
        return Markings(length: l, width: w, marks: marks)
    }

    private static func volleyball() -> Markings {
        var marks: [Mark] = [box(18, 9), across(3, 9), across(-3, 9)]
        marks.append(net(9, overhang: 0.5))
        return Markings(length: 18, width: 9, marks: marks)
    }

    private static func tableTennis() -> Markings {
        let (l, w): (Double, Double) = (2.74, 1.525)
        let marks: [Mark] = [box(l, w), line([Point(-l / 2, 0), Point(l / 2, 0)]), net(w, overhang: 0.1525)]
        return Markings(length: l, width: w, marks: marks)
    }

    /// The front wall at -x; the short line 5.44 m from it, the half-court
    /// line and the service boxes behind it.
    private static func squash() -> Markings {
        let (l, w, short, side): (Double, Double, Double, Double) = (9.75, 6.4, 5.44, 1.6)
        let sx: Double = -l / 2 + short
        var marks: [Mark] = [box(l, w)]
        marks.append(line([Point(-l / 2, -w / 2), Point(-l / 2, w / 2)], .wall))
        marks.append(across(sx, w))
        marks.append(line([Point(sx, 0), Point(l / 2, 0)]))
        for s in [1.0, -1.0] {
            let y: Double = s * (w / 2 - side)
            marks.append(line([Point(sx, y), Point(sx + side, y), Point(sx + side, s * w / 2)]))
        }
        return Markings(length: l, width: w, marks: marks)
    }

    private static func basketball() -> Markings {
        let (l, w, key, keyWidth): (Double, Double, Double, Double) = (28, 15, 5.8, 4.9)
        let (basket, three, corner): (Double, Double, Double) = (1.575, 6.75, 6.6)
        let sweep: Double = asin(corner / three)
        let reach: Double = cos(sweep) * three
        var marks: [Mark] = [box(l, w), across(0, w), arc(.zero, 1.8, 0, 2 * Double.pi, steps: 32)]
        for s in [1.0, -1.0] {
            let hoop: Double = s * (l / 2 - basket)
            let from: Double = s > 0 ? Double.pi - sweep : -sweep
            let to: Double = s > 0 ? Double.pi + sweep : sweep
            marks.append(endBox(at: s * l / 2, depth: key, width: keyWidth, toward: s))
            marks.append(arc(Point(hoop, 0), three, from, to, steps: 32))
            for side in [1.0, -1.0] {
                marks.append(line([Point(s * l / 2, side * corner), Point(hoop - s * reach, side * corner)]))
            }
        }
        return Markings(length: l, width: w, marks: marks)
    }

    /// Handball (40 × 20) and futsal, which adds a centre circle.
    private static func goalCourt(centreCircle: Double?) -> Markings {
        var marks: [Mark] = [box(40, 20), across(0, 20)]
        if let r = centreCircle { marks.append(arc(.zero, r, 0, 2 * Double.pi, steps: 32)) }
        marks += goalArea(half: 20, r: 6, post: 1.5)
        return Markings(length: 40, width: 20, marks: marks)
    }

    private static func football() -> Markings {
        let (l, w, boxDepth, boxWidth): (Double, Double, Double, Double) = (105, 68, 16.5, 40.32)
        let (goalDepth, goalWidth, spot, r): (Double, Double, Double, Double) = (5.5, 18.32, 11, 9.15)
        // The penalty arc is the part of the spot's circle outside the box.
        let sweep: Double = acos((boxDepth - spot) / r)
        var marks: [Mark] = [box(l, w), across(0, w), arc(.zero, r, 0, 2 * Double.pi, steps: 48)]
        for s in [1.0, -1.0] {
            let x: Double = s * l / 2
            let from: Double = s > 0 ? Double.pi - sweep : -sweep
            let to: Double = s > 0 ? Double.pi + sweep : sweep
            marks.append(endBox(at: x, depth: boxDepth, width: boxWidth, toward: s))
            marks.append(endBox(at: x, depth: goalDepth, width: goalWidth, toward: s))
            marks.append(arc(Point(s * (l / 2 - spot), 0), r, from, to, steps: 16))
        }
        return Markings(length: l, width: w, marks: marks)
    }

    /// A sport's lines placed on a court: scaled down when the outline is
    /// smaller than the standard court, never up (a larger outline is the court
    /// with its run-off around it), centred and turned with it.
    public static func place(_ m: Markings, on frame: Frame) -> [Mark] {
        guard frame.length > 0, frame.width > 0 else { return [] }
        let s = min(1, frame.length / m.length, frame.width / m.width)
        let (c, sn) = (cos(frame.angle), sin(frame.angle))
        return m.marks.map { mark in
            Mark(points: mark.points.map { p in
                frame.center + s * Point(p.x * c - p.y * sn, p.x * sn + p.y * c)
            }, stroke: mark.stroke)
        }
    }

    // MARK: - Fitting it on the screen

    /// The box around every shape.
    public static func bounds(_ shapes: [[Point]]) -> (min: Point, max: Point) {
        let all = shapes.flatMap { $0 }
        guard var low = all.first else { return (.zero, .zero) }
        var high = low
        for p in all {
            low = pointwiseMin(low, p)
            high = pointwiseMax(high, p)
        }
        return (low, high)
    }

    /// Metres to points on the screen, the whole plan fitted inside `size`
    /// less `pad` on every side, north up.
    public struct Fit: Equatable, Sendable {
        /// Screen points per metre.
        public var scale: Double
        public var origin: CGPoint

        public func screen(_ p: Point) -> CGPoint {
            CGPoint(x: origin.x + p.x * scale, y: origin.y - p.y * scale)
        }

        public func plan(_ s: CGPoint) -> Point {
            Point((s.x - origin.x) / scale, (origin.y - s.y) / scale)
        }
    }

    public static func fit(_ bounds: (min: Point, max: Point), in size: CGSize, pad: Double) -> Fit {
        let w = max(bounds.max.x - bounds.min.x, 1)
        let h = max(bounds.max.y - bounds.min.y, 1)
        let scale = max(min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h), 0.01)
        return Fit(
            scale: scale,
            origin: CGPoint(
                x: pad + (size.width - 2 * pad - w * scale) / 2 - bounds.min.x * scale,
                y: pad + (size.height - 2 * pad - h * scale) / 2 + bounds.max.y * scale
            )
        )
    }

    /// Whether `p` lies inside the polygon (even-odd ray casting).
    public static func contains(_ p: Point, in polygon: [Point]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let (a, b) = (polygon[i], polygon[j])
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
