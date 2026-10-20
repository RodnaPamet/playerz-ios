import Foundation
import Testing

@testable import PlayerzAPI

/// The venue plan (#25): the server's answers decoded through the generated
/// client, and the drawing's numbers, which match the web's (`plan-geometry.ts`).
///
/// Captured from `GET /venues/{id}/plan` on the perf database: Plovdiv's six
/// tennis courts with their run-off, from OpenStreetMap and turned 30°, with
/// the grounds and a building; Sofia's four padel courts drawn by the club; a
/// venue with no plan; and an unknown venue.
@Suite("The venue plan")
struct VenuePlanTests {
    private typealias G = VenuePlanGeometry

    private func client(_ status: Int, _ body: String) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: ["getVenuePlan": (status, body)])
        )
    }

    private func plan(_ body: String) async throws -> Components.Schemas.VenuePlan {
        try await client(200, body).getVenuePlan(path: .init(id: "v")).ok.body.json.data
    }

    @Test func courtsFromOpenStreetMapWithTheGrounds() async throws {
        let plan = try await plan(OSM)
        #expect(plan.courts.count == 6)
        #expect(plan.courts.allSatisfy { $0.sport == "TENNIS" && G.points($0.outline)?.count == 4 })
        #expect(plan.features.map(\.kind) == ["GROUNDS", "BUILDING"])
        #expect(plan.attribution == "OpenStreetMap")
    }

    @Test func courtsTheClubDrew() async throws {
        let plan = try await plan(CLUB)
        #expect(plan.courts.map(\.name) == ["Court 1", "Court 2", "Court 3", "Court 4"])
        #expect(plan.features.isEmpty && plan.attribution == nil)
    }

    @Test func noPlanAndNoVenue() async throws {
        let none = try await plan(NONE)
        #expect(none.courts.isEmpty && none.features.isEmpty)
        let missing = try await client(404, MISSING).getVenuePlan(path: .init(id: "v"))
        #expect(try missing.notFound.body.json.error.code == "NOT_FOUND")
    }

    @Test func aTurnedCourtsFrameAndLines() async throws {
        let court = try #require(try await plan(OSM).courts.first)
        let frame = G.frame(of: try #require(G.points(court.outline)))
        // 36 × 18 m of court and run-off, its length turned 30° from north.
        #expect(abs(frame.length - 36) < 0.05 && abs(frame.width - 18) < 0.05)
        #expect(abs(frame.angle * 180 / .pi - 120) < 0.1)
        // The tennis lines keep their true size inside the run-off.
        let lines = G.place(try #require(G.markings(for: "TENNIS")), on: frame)
        let outer = lines[0].points
        let length = (0..<4).map { simd_distance_between(outer[$0], outer[$0 + 1]) }.max() ?? 0
        #expect(abs(length - 23.77) < 0.01)
    }

    @Test(arguments: ["TENNIS", "PADEL", "BADMINTON", "PICKLEBALL", "SQUASH", "BASKETBALL", "FOOTBALL", "FOOTBALL5", "HANDBALL", "VOLLEYBALL", "BEACH_VOLLEYBALL", "BEACH_TENNIS", "TABLE_TENNIS"])
    func eachSportsLinesStayOnItsCourt(sport: String) throws {
        let m = try #require(G.markings(for: sport))
        for mark in m.marks {
            for p in mark.points {
                #expect(abs(p.x) <= m.length / 2 + 1e-9)
                #expect(abs(p.y) <= m.width / 2 + (mark.stroke == .net ? 1 : 1e-9))
            }
        }
    }

    @Test func aSportWithoutLinesIsItsOutline() {
        #expect(G.markings(for: "KARTING") == nil)
        #expect(G.markings(for: "SOMETHING_NEW") == nil)
    }

    @Test func theFitAndTheWayBack() throws {
        let shapes = [[G.Point(0, 0), G.Point(20, 0), G.Point(20, 10), G.Point(0, 10)], [G.Point(22, 0), G.Point(42, 0), G.Point(42, 10), G.Point(22, 10)]]
        let fit = G.fit(G.bounds(shapes), in: CGSize(width: 340, height: 220), pad: 12)
        let topLeft = fit.screen(G.Point(0, 10))
        let bottomRight = fit.screen(G.Point(42, 0))
        #expect(abs(topLeft.x + bottomRight.x - 340) < 1e-6)
        #expect(abs(topLeft.y + bottomRight.y - 220) < 1e-6)
        #expect(topLeft.x >= 12 - 1e-9 && bottomRight.x <= 340 - 12 + 1e-9)
        let back = fit.plan(fit.screen(G.Point(7.5, 3.25)))
        #expect(abs(back.x - 7.5) < 1e-9 && abs(back.y - 3.25) < 1e-9)
        #expect(G.contains(G.Point(10, 5), in: shapes[0]))
        #expect(!G.contains(G.Point(21, 5), in: shapes[0]))
    }

    @Test func timeFirst() {
        let at = { (h: Double) in Date(timeIntervalSince1970: h * 3600) }
        #expect(VenuePlanTimes.starts([[at(10), at(8)], [at(9), at(10)]]) == [at(8), at(9), at(10)])
        #expect(VenuePlanTimes.later([at(8), at(9), at(10), at(11), at(12)], after: at(8)) == [at(9), at(10), at(11)])
        #expect(VenuePlanTimes.later([at(8)], after: at(8)).isEmpty)
    }
}

private func simd_distance_between(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    ((a - b) * (a - b)).sum().squareRoot()
}

private let OSM = #"{"data":{"venueId":"cmvh3lq4t0017y5iz4mcb4wq5","courts":[{"resourceId":"cmvh3lq4y0018y5iz33nyrwb4","name":"Court 1","sport":"TENNIS","resourceType":"COURT","outline":[[-6.18,-46.29],[9.41,-37.29],[-8.59,-6.12],[-24.18,-15.12]],"source":"OSM"},{"resourceId":"cmvh3lq56001hy5izocn1w5w5","name":"Court 2","sport":"TENNIS","resourceType":"COURT","outline":[[10.27,-36.79],[25.86,-27.79],[7.86,3.38],[-7.73,-5.62]],"source":"OSM"},{"resourceId":"cmvh3lq5e001qy5iz54strk18","name":"Court 3","sport":"TENNIS","resourceType":"COURT","outline":[[26.73,-27.29],[42.32,-18.29],[24.32,12.88],[8.73,3.88]],"source":"OSM"},{"resourceId":"cmvh3lq5l001zy5iz1jzhi294","name":"Court 4","sport":"TENNIS","resourceType":"COURT","outline":[[-24.68,-14.25],[-9.09,-5.25],[-27.09,25.93],[-42.68,16.93]],"source":"OSM"},{"resourceId":"cmvh3lq5t0028y5izv194ted0","name":"Court 5","sport":"TENNIS","resourceType":"COURT","outline":[[-8.23,-4.75],[7.36,4.25],[-10.64,35.43],[-26.23,26.43]],"source":"OSM"},{"resourceId":"cmvh3lq61002hy5izfvwv0niy","name":"Court 6","sport":"TENNIS","resourceType":"COURT","outline":[[8.23,4.75],[23.82,13.75],[5.82,44.93],[-9.77,35.93]],"source":"OSM"}],"features":[{"kind":"GROUNDS","outline":[[-7.58,-52.87],[49.58,-19.87],[8.58,51.14],[-48.58,18.14]],"source":"OSM"},{"kind":"BUILDING","outline":[[-48.58,18.14],[-28.66,29.64],[-34.66,40.03],[-54.58,28.53]],"source":"OSM"}],"attribution":"OpenStreetMap"}}"#
private let CLUB = #"{"data":{"venueId":"cmvh3lq1q0003y5izfm27jgng","courts":[{"resourceId":"cmvh3lq3b0004y5izsxsalxcz","name":"Court 1","sport":"PADEL","resourceType":"COURT","outline":[[-21,-11],[-1,-11],[-1,-1],[-21,-1]],"source":"CLUB"},{"resourceId":"cmvh3lq3t000dy5iz0rwl7r11","name":"Court 2","sport":"PADEL","resourceType":"COURT","outline":[[1,-11],[21,-11],[21,-1],[1,-1]],"source":"CLUB"},{"resourceId":"cmvh3lq41000my5iz3813xunz","name":"Court 3","sport":"PADEL","resourceType":"COURT","outline":[[-21,1],[-1,1],[-1,11],[-21,11]],"source":"CLUB"},{"resourceId":"cmvh3lq49000vy5izmfveo1cq","name":"Court 4","sport":"PADEL","resourceType":"COURT","outline":[[1,1],[21,1],[21,11],[1,11]],"source":"CLUB"}],"features":[],"attribution":null}}"#
private let NONE = #"{"data":{"venueId":"cmvh3lqfe002cw4izj246hyg4","courts":[],"features":[],"attribution":null}}"#
private let MISSING = #"{"error":{"code":"NOT_FOUND","message":"Venue not found","requestId":"cc6c6fd9-5504-4c5c-8407-e7712aa3c17f"}}"#
