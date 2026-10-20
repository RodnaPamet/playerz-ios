import PlayerzAPI

/// A venue's plan (#25), worked out once from `GET /venues/{id}/plan`: each
/// court's outline, the frame its name sits on and its sport's lines, and the
/// plan's other shapes. Nil when no court is on it, so the screen keeps its
/// list alone.
struct VenuePlanDrawing {
    typealias G = VenuePlanGeometry

    struct Court: Identifiable {
        let id: String
        let name: String
        let outline: [G.Point]
        let frame: G.Frame
        let marks: [G.Mark]
    }

    struct Shape {
        /// `GROUNDS`, `BUILDING`, `ENTRANCE`, or one this app does not know yet.
        let kind: String
        let outline: [G.Point]
    }

    let courts: [Court]
    let shapes: [Shape]
    let bounds: (min: G.Point, max: G.Point)
    /// ODbL asks for «© OpenStreetMap contributors» wherever its shapes show.
    let creditsOpenStreetMap: Bool

    init?(_ plan: Components.Schemas.VenuePlan) {
        let courts = plan.courts.compactMap { court -> Court? in
            guard let outline = G.points(court.outline) else { return nil }
            let frame = G.frame(of: outline)
            return Court(
                id: court.resourceId,
                name: court.name,
                outline: outline,
                frame: frame,
                marks: G.markings(for: court.sport).map { G.place($0, on: frame) } ?? []
            )
        }
        guard !courts.isEmpty else { return nil }
        let shapes = plan.features.compactMap { shape in
            G.points(shape.outline).map { Shape(kind: shape.kind, outline: $0) }
        }
        self.courts = courts
        self.shapes = shapes
        bounds = G.bounds(courts.map(\.outline) + shapes.map(\.outline))
        creditsOpenStreetMap = plan.attribution == "OpenStreetMap"
    }
}
