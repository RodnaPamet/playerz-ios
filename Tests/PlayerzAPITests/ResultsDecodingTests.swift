import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for results and ratings (playerz-ios#18), decoded
/// through the generated client.
///
/// Captured from the server's routes on the perf database, ranking on: a
/// padel doubles booking reported by the player and confirmed by the other
/// side (a teammate answering is refused); a tennis singles reported by the
/// opponent, which the player disputes, after which answering again is
/// refused; the player's ratings, and the club's leaderboard, empty because
/// nobody there has 5 confirmed matches yet (one ranked row is added to it in
/// the schema's shape).
@Suite("Results decode the server's JSON")
struct ResultsDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func aPlayedBookingThatMayBeReported() async throws {
        let state = try await client(["getBookingResult": (200, CAN_REPORT)])
            .getBookingResult(path: .init(id: "b")).ok.body.json.data
        #expect(state.canReport)
        #expect(state.result == nil)
        #expect(state.format == .PERIODS)
        #expect(state.players.count == 4)
        #expect(state.fixedSides == nil && state.pointsTotal == nil)
        // The server writes milliseconds here; the client reads them.
        #expect(state.reportableUntil != nil)
        // What the editor starts from: two a side, two sets.
        let draft = ResultDraft(players: state.players.map(\.userId), format: .periods)
        #expect(draft.seats.values.filter { $0 == .side(0) }.count == 2)
    }

    @Test func reportingAnswersTheResultWaiting() async throws {
        let state = try await client(["reportBookingResult": (201, REPORTED)])
            .reportBookingResult(path: .init(id: "b"), body: .json(.init(sides: [["a"], ["b"]], score: [[6, 4]])))
            .created.body.json.data
        let result = try #require(state.result)
        #expect(result.status == .REPORTED)
        #expect(result.reportedByMe && !result.canAnswer)
        #expect(result.score == [[6, 4], [3, 6], [7, 5]])
        #expect(result.winnerSide == 0)
        #expect(result.autoConfirmAt != nil)
    }

    @Test func confirmedByTheOtherSide() async throws {
        let answered = try await client(["confirmResult": (200, CONFIRMED)])
            .confirmResult(path: .init(id: "r")).ok.body.json.data
        #expect(answered.status == .CONFIRMED)
        let state = try await client(["getBookingResult": (200, CONFIRMED_STATE)])
            .getBookingResult(path: .init(id: "b")).ok.body.json.data
        #expect(state.result?.status == .CONFIRMED)
        #expect(state.canReport == false)
    }

    @Test func toAnswerThenDisputed() async throws {
        let waiting = try await client(["getBookingResult": (200, TO_ANSWER)])
            .getBookingResult(path: .init(id: "b")).ok.body.json.data
        #expect(waiting.result?.canAnswer == true)
        #expect(waiting.result?.reportedByMe == false)
        let disputed = try await client(["rejectResult": (200, REJECTED)])
            .rejectResult(path: .init(id: "r"), body: .json(.init(note: "6:4"))).ok.body.json.data
        #expect(disputed.status == .REJECTED)
        let state = try await client(["getBookingResult": (200, REJECTED_STATE)])
            .getBookingResult(path: .init(id: "b")).ok.body.json.data
        #expect(state.result?.status == .REJECTED)
        #expect(state.result?.canAnswer == false)
    }

    @Test func refusalsCarryTheirCodes() async throws {
        let teammate = try await client(["confirmResult": (403, NOT_YOURS)]).confirmResult(path: .init(id: "r"))
        #expect(try teammate.forbidden.body.json.error.code == "RESULT_NOT_YOURS_TO_ANSWER")
        let again = try await client(["confirmResult": (409, NOT_AWAITING)]).confirmResult(path: .init(id: "r"))
        #expect(try again.conflict.body.json.error.code == "RESULT_NOT_AWAITING")
    }

    @Test func myRatings() async throws {
        let ratings = try await client(["getMyRatings": (200, RATINGS)]).getMyRatings().ok.body.json.data
        #expect(ratings._public)
        let padel = try #require(ratings.items.first)
        #expect(padel.sport == "PADEL")
        #expect(padel.provisional)
        #expect(padel.matchesPlayed == 1)
        #expect(padel.points != nil)
    }

    @Test func aClubsLeaderboard() async throws {
        let empty = try await client(["getClubLeaderboard": (200, LEADERBOARD_EMPTY)])
            .getClubLeaderboard(path: .init(slug: "c")).ok.body.json.data
        #expect(empty.sports == ["PADEL"] && empty.sport == "PADEL" && empty.rows.isEmpty)
        let ranked = try await client(["getClubLeaderboard": (200, LEADERBOARD_RANKED)])
            .getClubLeaderboard(path: .init(slug: "c")).ok.body.json.data
        #expect(ranked.rows.first?.level == 5.2)
    }
}

private let CAN_REPORT = #"{"data":{"result":null,"canReport":true,"reportableUntil":"2026-10-22T17:30:00.000Z","format":"PERIODS","players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false},{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}],"fixedSides":null,"pointsTotal":null}}"#
private let REPORTED = #"{"data":{"result":{"id":"cmvgyfpa70009kbizbq22t22q","status":"REPORTED","sides":[[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],[{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}]],"score":[[6,4],[3,6],[7,5]],"winnerSide":0,"reportedByMe":true,"reportedAt":"2026-10-20T17:26:00.872Z","autoConfirmAt":"2026-10-22T17:26:00.872Z","canAnswer":false},"canReport":false,"reportableUntil":null,"format":"PERIODS","players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false},{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}],"fixedSides":null,"pointsTotal":null}}"#
private let CONFIRMED_STATE = #"{"data":{"result":{"id":"cmvgyfpa70009kbizbq22t22q","status":"CONFIRMED","sides":[[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],[{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}]],"score":[[6,4],[3,6],[7,5]],"winnerSide":0,"reportedByMe":true,"reportedAt":"2026-10-20T17:26:00.872Z","autoConfirmAt":"2026-10-22T17:26:00.872Z","canAnswer":false},"canReport":false,"reportableUntil":null,"format":"PERIODS","players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false},{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}],"fixedSides":null,"pointsTotal":null}}"#
private let CONFIRMED = #"{"data":{"status":"CONFIRMED"}}"#
private let TO_ANSWER = #"{"data":{"result":{"id":"cmvgyfpj4000nkbizmuf4lw4e","status":"REPORTED","sides":[[{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false}]],"score":[[6,2],[6,3]],"winnerSide":0,"reportedByMe":false,"reportedAt":"2026-10-20T17:26:01.175Z","autoConfirmAt":"2026-10-22T17:26:01.175Z","canAnswer":true},"canReport":false,"reportableUntil":null,"format":"PERIODS","players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],"fixedSides":null,"pointsTotal":null}}"#
private let REJECTED = #"{"data":{"status":"REJECTED"}}"#
private let REJECTED_STATE = #"{"data":{"result":{"id":"cmvgyfpj4000nkbizmuf4lw4e","status":"REJECTED","sides":[[{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false}]],"score":[[6,2],[6,3]],"winnerSide":0,"reportedByMe":false,"reportedAt":"2026-10-20T17:26:01.175Z","autoConfirmAt":"2026-10-22T17:26:01.175Z","canAnswer":false},"canReport":false,"reportableUntil":null,"format":"PERIODS","players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}],"fixedSides":null,"pointsTotal":null}}"#
private let NOT_YOURS = #"{"error":{"code":"RESULT_NOT_YOURS_TO_ANSWER","message":"Only a player on the other side answers a result.","requestId":"4f5631d6-facc-4b58-8daf-ccead0e932e4"}}"#
private let NOT_AWAITING = #"{"error":{"code":"RESULT_NOT_AWAITING","message":"This result is not waiting for that any more.","requestId":"8632aae9-72bd-455a-9017-8f181f312809"}}"#
private let RATINGS = #"{"data":{"public":true,"items":[{"sport":"PADEL","level":4.5,"provisional":true,"points":2.43,"matchesPlayed":1,"lastPlayedAt":"2026-10-20T17:26:01.113Z"}]}}"#
private let LEADERBOARD_EMPTY = #"{"data":{"sports":["PADEL"],"sport":"PADEL","rows":[]}}"#
private let LEADERBOARD_RANKED = #"{"data":{"sports":["PADEL"],"sport":"PADEL","rows":[{"rank":1,"userId":"u1","name":"Мария Георгиева","avatarUrl":null,"level":5.2,"matchesPlayed":7}]}}"#
