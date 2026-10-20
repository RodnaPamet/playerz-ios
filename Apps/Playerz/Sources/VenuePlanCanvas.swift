import PlayerzAPI
import SwiftUI

/// The plan itself (#25): every court drawn with its sport's lines, free,
/// taken (hatched, so not told by colour alone) or the player's pick, on the
/// venue's own grounds; our drawing, with no map under it. A tap on a court
/// chooses it; two fingers zoom, and one finger then moves the plan.
///
/// VoiceOver reads it as the list of courts with each one's state, every
/// court a button that chooses it, as the canvas does for a finger.
struct VenuePlanCanvas: View {
    let drawing: VenuePlanDrawing
    let look: (String) -> VenuePlanMoment.Look
    /// What VoiceOver says for a court: its name and its state at the time.
    let describe: (VenuePlanDrawing.Court) -> String
    let choose: (String) -> Void

    /// The canvas's size, for the fit and the hit test.
    @State private var size: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    private typealias G = VenuePlanGeometry
    private static let maxZoom: CGFloat = 6

    var body: some View {
        let view = viewFor(size)
        Canvas { context, _ in
            paint(&context, view)
        }
        .frame(height: 240)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .contentShape(Rectangle())
        // A tap needs its location, to know which court it fell on.
        .gesture(SpatialTapGesture().onEnded { value in tapped(at: value.location, view) })
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value.magnification }
                .onEnded(pinched)
        )
        // One finger moves the plan only while it is zoomed: otherwise it
        // scrolls the screen, as everywhere else in the list.
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($drag) { value, state, _ in state = value.translation }
                .onEnded(dragged),
            isEnabled: zoom > 1
        )
        .overlay(alignment: .bottomTrailing) {
            if zoom > 1 {
                Button(String(localized: "venuePlan.wholePlan"), action: showWholePlan)
                    .buttonStyle(.bordered)
                    .padding(8)
            }
        }
        .accessibilityRepresentation {
            VStack {
                ForEach(drawing.courts) { court in
                    Button(describe(court)) { choose(court.id) }
                }
            }
        }
    }

    private func tapped(at location: CGPoint, _ view: ViewState) {
        if let id = court(at: location, view) { choose(id) }
    }

    private func pinched(_ value: MagnifyGesture.Value) {
        zoom = min(Self.maxZoom, max(1, zoom * value.magnification))
        offset = clamped(offset, zoom, size)
    }

    private func dragged(_ value: DragGesture.Value) {
        offset = clamped(offset + value.translation, zoom, size)
    }

    private func showWholePlan() {
        withAnimation {
            zoom = 1
            offset = .zero
        }
    }

    // MARK: - Where things are

    /// The fit, and the zoom and pan on top of it.
    private struct ViewState {
        let fit: G.Fit
        let k: CGFloat
        let shift: CGSize
        let center: CGPoint

        func screen(_ p: G.Point) -> CGPoint {
            let s = fit.screen(p)
            return CGPoint(
                x: center.x + (s.x - center.x) * k + shift.width,
                y: center.y + (s.y - center.y) * k + shift.height
            )
        }

        func plan(_ s: CGPoint) -> G.Point {
            fit.plan(CGPoint(
                x: center.x + (s.x - center.x - shift.width) / k,
                y: center.y + (s.y - center.y - shift.height) / k
            ))
        }
    }

    private func viewFor(_ size: CGSize) -> ViewState {
        let k = min(Self.maxZoom, max(1, zoom * pinch))
        return ViewState(
            // Before the first layout the size is zero; the fit then is
            // harmless, and redrawn as soon as the size arrives.
            fit: G.fit(drawing.bounds, in: size, pad: 12),
            k: k,
            shift: clamped(offset + drag, k, size),
            center: CGPoint(x: size.width / 2, y: size.height / 2)
        )
    }

    /// At zoom k the plan is k times the box, so it may move by at most half
    /// of what overhangs on each side; at 1 it does not move.
    private func clamped(_ shift: CGSize, _ k: CGFloat, _ size: CGSize) -> CGSize {
        let (x, y) = (size.width * (k - 1) / 2, size.height * (k - 1) / 2)
        return CGSize(width: min(x, max(-x, shift.width)), height: min(y, max(-y, shift.height)))
    }

    private func court(at location: CGPoint, _ view: ViewState) -> String? {
        let p = view.plan(location)
        return drawing.courts.last { G.contains(p, in: $0.outline) }?.id
    }

    // MARK: - Painting

    private func path(_ points: [G.Point], _ view: ViewState, closed: Bool = true) -> Path {
        Path { path in
            path.addLines(points.map(view.screen))
            if closed { path.closeSubpath() }
        }
    }

    private func paint(_ context: inout GraphicsContext, _ view: ViewState) {
        let metre = view.fit.scale * view.k

        for shape in drawing.shapes {
            let outline = path(shape.outline, view)
            switch shape.kind {
            case "BUILDING": context.fill(outline, with: .style(.fill.secondary))
            case "ENTRANCE": context.fill(outline, with: .color(.orange))
            default: context.fill(outline, with: .style(.fill.quaternary))
            }
            context.stroke(outline, with: .style(.separator), lineWidth: 1)
        }

        for court in drawing.courts {
            let state = look(court.id)
            let outline = path(court.outline, view)
            switch state {
            case .free: context.fill(outline, with: .color(.green))
            case .picked: context.fill(outline, with: .color(.accentColor))
            case .taken:
                context.fill(outline, with: .style(.fill.tertiary))
                hatch(&context, outline)
            }
            let lines: Color = state == .taken ? .secondary : .white.opacity(0.85)
            for mark in court.marks {
                let width = mark.stroke == .line ? min(2, max(1, metre * 0.08)) : min(4, max(1, metre * 0.2))
                context.stroke(path(mark.points, view, closed: false), with: .color(lines), lineWidth: width)
            }
            context.stroke(
                outline,
                with: state == .picked ? .color(.accentColor) : .style(.separator),
                lineWidth: state == .picked ? 3 : 1.5
            )
        }

        // The names last, on a pill of the background, so they read on any fill.
        for court in drawing.courts {
            let name = context.resolve(Text(court.name).font(.caption.bold()))
            let measured = name.measure(in: CGSize(width: 200, height: 40))
            let width = measured.width + 12
            // Across the court's short side, or it would run into its
            // neighbours; VoiceOver and a zoom still give every name.
            guard width <= court.frame.width * metre else { continue }
            let at = view.screen(court.frame.center)
            let height = measured.height + 4
            let pill = CGRect(x: at.x - width / 2, y: at.y - height / 2, width: width, height: height)
            context.fill(Path(roundedRect: pill, cornerRadius: height / 2), with: .style(.background))
            context.draw(name, at: at)
        }
    }

    /// Diagonal lines across a taken court.
    private func hatch(_ context: inout GraphicsContext, _ outline: Path) {
        let box = outline.boundingRect
        var lines = Path()
        var x = box.minX - box.height
        while x < box.maxX {
            lines.move(to: CGPoint(x: x, y: box.maxY))
            lines.addLine(to: CGPoint(x: x + box.height, y: box.minY))
            x += 7
        }
        var clipped = context
        clipped.clip(to: outline)
        clipped.stroke(lines, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
    }
}

private func + (a: CGSize, b: CGSize) -> CGSize {
    CGSize(width: a.width + b.width, height: a.height + b.height)
}
