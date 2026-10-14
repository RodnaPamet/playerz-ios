import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for open play (#376), decoded through the generated
/// client (#510).
///
/// The spec guards the server's ENDPOINTS, not their shapes (see README). These
/// bodies were captured from the server's own route handlers on a real
/// database: a booker opens a game, a player asks, the booker accepts, and the
/// player asks again and is refused. Decoding them through `Client`, with its
/// own date transcoder, is what proves the Игри screens read what the server
/// writes: milliseconds in the dates, nulls where a value is absent, and the
/// nested viewer.
@Suite("Open play decodes the server's JSON")
struct OpenPlayDecodingTests {
    private static let replies: [String: (Int, String)] = [
        "listOpenGames": (200, GAMES),
        "getOpenGame": (200, GAME),
        "askToJoinGame": (201, ASK),
        "listMyGameRequests": (200, MINE),
        "getBookingGame": (200, BOOKING_GAME),
        "acceptGameRequest": (200, ACCEPTED),
        "openBookingGame": (200, OPENED),
    ]

    private func client(_ override: [String: (Int, String)] = [:]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: Self.replies.merging(override) { _, new in new })
        )
    }

    @Test func theListOfGames() async throws {
        let page = try await client().listOpenGames(.init()).ok.body.json.data
        let game = try #require(page.items.first)
        #expect(page.nextCursor == nil)
        #expect(game.sport == .PADEL)
        #expect(game.spotsLeft == 2)
        #expect(game.levelMin == 3 && game.levelMax == 5)
        #expect(game.booker.firstName == "Иван")
        #expect(game.viewer?.request == nil)
        // The server writes milliseconds; the hour survives the trip.
        #expect(game.endTs.timeIntervalSince(game.startTs) == 3600)
    }

    @Test func askingAnswersTheGameWithTheRequest() async throws {
        let response = try await client().askToJoinGame(path: .init(id: "g"), body: .json(.init(note: "x")))
        let game = try response.created.body.json.data
        #expect(game.viewer?.request?.status == .PENDING)
    }

    @Test func myRequests() async throws {
        let mine = try await client().listMyGameRequests().ok.body.json.data
        #expect(mine.first?.status == .PENDING)
        #expect(mine.first?.note == "Играя от 3 години")
    }

    @Test func theBookersViewWithARequest() async throws {
        let game = try await client().getBookingGame(path: .init(id: "b")).ok.body.json.data
        #expect(game.viewerRole == .BOOKER)
        #expect(game.game?.open == true)
        let request = try #require(game.requests.first)
        #expect(request.status == .PENDING)
        #expect(request.player.name == "Мария Георгиева")
        #expect(request.player.sports.first?.level == 4)
    }

    @Test func acceptedAndTheParticipantsView() async throws {
        let accepted = try await client()
            .acceptGameRequest(path: .init(id: "b", requestId: "r")).ok.body.json.data
        #expect(accepted.requests.first?.status == .ACCEPTED)
        let theirs = try await client(["getBookingGame": (200, PARTICIPANT)])
            .getBookingGame(path: .init(id: "b")).ok.body.json.data
        #expect(theirs.viewerRole == .PARTICIPANT)
        #expect(theirs.myRequest?.status == .ACCEPTED)
    }

    @Test func datesWithAndWithoutMilliseconds() throws {
        let transcoder = ServerDateTranscoder()
        let withFraction = try transcoder.decode("2026-10-16T15:56:01.418Z")
        let without = try transcoder.decode("2026-10-16T15:56:01Z")
        #expect(abs(withFraction.timeIntervalSince(without) - 0.418) < 0.001)
        #expect(try transcoder.encode(without) == "2026-10-16T15:56:01.000Z")
    }

    @Test func aRefusalCarriesItsCode() async throws {
        let response = try await client(["askToJoinGame": (409, REFUSED)])
            .askToJoinGame(path: .init(id: "g"), body: .json(.init()))
        let error = try response.conflict.body.json
        #expect(error.error.code == "ALREADY_PLAYING")
    }
}


// Captured 2026-10-14 from the server's v1 route handlers (see the suite's comment).
private let GAMES = #"{"data":{"items":[{"id":"cmv8akv31000cbtiz30wp6y04","sport":"PADEL","resourceType":"COURT","courtName":"Court 1","venue":{"id":"cmv8akuuq0003btizu6idzc93","slug":"venue-iu4jx0c0","name":"Venue iu4jx0c0","city":"Sofia"},"startTs":"2026-10-16T15:56:01.418Z","endTs":"2026-10-16T16:56:01.418Z","timezone":"Europe/Sofia","cutoffAt":"2026-10-15T15:56:01.418Z","capacity":4,"playersCount":1,"spotsLeft":2,"open":true,"levelMin":3,"levelMax":5,"note":"Приятелска игра","booker":{"firstName":"Иван","avatarUrl":null},"viewer":{"isBooker":false,"isPlaying":false,"bookingId":null,"request":null,"levelFits":null}}],"nextCursor":null}}"#
private let GAME = #"{"data":{"id":"cmv8akv31000cbtiz30wp6y04","sport":"PADEL","resourceType":"COURT","courtName":"Court 1","venue":{"id":"cmv8akuuq0003btizu6idzc93","slug":"venue-iu4jx0c0","name":"Venue iu4jx0c0","city":"Sofia"},"startTs":"2026-10-16T15:56:01.418Z","endTs":"2026-10-16T16:56:01.418Z","timezone":"Europe/Sofia","cutoffAt":"2026-10-15T15:56:01.418Z","capacity":4,"playersCount":1,"spotsLeft":2,"open":true,"levelMin":3,"levelMax":5,"note":"Приятелска игра","booker":{"firstName":"Иван","avatarUrl":null},"viewer":{"isBooker":false,"isPlaying":false,"bookingId":null,"request":{"id":"cmv8akv6s000ebtiz3tykqjre","status":"PENDING"},"levelFits":null}}}"#
private let ASK = #"{"data":{"id":"cmv8akv31000cbtiz30wp6y04","sport":"PADEL","resourceType":"COURT","courtName":"Court 1","venue":{"id":"cmv8akuuq0003btizu6idzc93","slug":"venue-iu4jx0c0","name":"Venue iu4jx0c0","city":"Sofia"},"startTs":"2026-10-16T15:56:01.418Z","endTs":"2026-10-16T16:56:01.418Z","timezone":"Europe/Sofia","cutoffAt":"2026-10-15T15:56:01.418Z","capacity":4,"playersCount":1,"spotsLeft":2,"open":true,"levelMin":3,"levelMax":5,"note":"Приятелска игра","booker":{"firstName":"Иван","avatarUrl":null},"viewer":{"isBooker":false,"isPlaying":false,"bookingId":null,"request":{"id":"cmv8akv6s000ebtiz3tykqjre","status":"PENDING"},"levelFits":null}}}"#
private let MINE = #"{"data":[{"id":"cmv8akv6s000ebtiz3tykqjre","status":"PENDING","note":"Играя от 3 години","askedAt":"2026-10-14T15:56:01.601Z","decidedAt":null,"bookingId":null,"game":{"id":"cmv8akv31000cbtiz30wp6y04","sport":"PADEL","resourceType":"COURT","courtName":"Court 1","venue":{"id":"cmv8akuuq0003btizu6idzc93","slug":"venue-iu4jx0c0","name":"Venue iu4jx0c0","city":"Sofia"},"startTs":"2026-10-16T15:56:01.418Z","endTs":"2026-10-16T16:56:01.418Z","timezone":"Europe/Sofia","cutoffAt":"2026-10-15T15:56:01.418Z","capacity":4,"playersCount":1,"spotsLeft":2,"open":true,"levelMin":3,"levelMax":5,"note":"Приятелска игра","booker":{"firstName":"Иван","avatarUrl":null},"viewer":{"isBooker":false,"isPlaying":false,"bookingId":null,"request":{"id":"cmv8akv6s000ebtiz3tykqjre","status":"PENDING"},"levelFits":null}}}]}"#
private let BOOKING_GAME = #"{"data":{"viewerRole":"BOOKER","bookingId":"cmv8akv0r000bbtizc6ueslgm","sport":"PADEL","cutoffAt":"2026-10-15T15:56:01.418Z","canOpen":true,"maxSpots":3,"game":{"id":"cmv8akv31000cbtiz30wp6y04","open":true,"closedAt":null,"spotsLeft":2,"accepted":0,"levelMin":3,"levelMax":5,"note":"Приятелска игра"},"requests":[{"id":"cmv8akv6s000ebtiz3tykqjre","status":"PENDING","note":"Играя от 3 години","askedAt":"2026-10-14T15:56:01.601Z","decidedAt":null,"participantId":null,"player":{"userId":"cmv8akuzz0008btiza40xgpvb","name":"Мария Георгиева","avatarUrl":null,"sports":[{"sport":"PADEL","level":4,"rating":null}],"deleted":false}}],"myRequest":null,"chatId":null}}"#
private let ACCEPTED = #"{"data":{"viewerRole":"BOOKER","bookingId":"cmv8akv0r000bbtizc6ueslgm","sport":"PADEL","cutoffAt":"2026-10-15T15:56:01.418Z","canOpen":true,"maxSpots":2,"game":{"id":"cmv8akv31000cbtiz30wp6y04","open":true,"closedAt":null,"spotsLeft":1,"accepted":1,"levelMin":3,"levelMax":5,"note":"Приятелска игра"},"requests":[{"id":"cmv8akv6s000ebtiz3tykqjre","status":"ACCEPTED","note":"Играя от 3 години","askedAt":"2026-10-14T15:56:01.601Z","decidedAt":"2026-10-14T15:56:01.787Z","participantId":"cmv8akvbd000ibtiz2t38f5mm","player":{"userId":"cmv8akuzz0008btiza40xgpvb","name":"Мария Георгиева","avatarUrl":null,"sports":[{"sport":"PADEL","level":4,"rating":null}],"deleted":false}}],"myRequest":null,"chatId":"c8txbva6ecrzfyr8qmmrn8flu"}}"#
private let OPENED = #"{"data":{"viewerRole":"BOOKER","bookingId":"cmv8akv0r000bbtizc6ueslgm","sport":"PADEL","cutoffAt":"2026-10-15T15:56:01.418Z","canOpen":true,"maxSpots":3,"game":{"id":"cmv8akv31000cbtiz30wp6y04","open":true,"closedAt":null,"spotsLeft":2,"accepted":0,"levelMin":3,"levelMax":5,"note":"Приятелска игра"},"requests":[],"myRequest":null,"chatId":null}}"#
private let PARTICIPANT = #"{"data":{"viewerRole":"PARTICIPANT","bookingId":"cmv8akv0r000bbtizc6ueslgm","sport":"PADEL","cutoffAt":"2026-10-15T15:56:01.418Z","canOpen":false,"maxSpots":2,"game":{"id":"cmv8akv31000cbtiz30wp6y04","open":true,"closedAt":null,"spotsLeft":1,"accepted":1,"levelMin":3,"levelMax":5,"note":"Приятелска игра"},"requests":[],"myRequest":{"id":"cmv8akv6s000ebtiz3tykqjre","status":"ACCEPTED"},"chatId":"c8txbva6ecrzfyr8qmmrn8flu"}}"#
private let REFUSED = #"{"error":{"code":"ALREADY_PLAYING","message":"You are already playing in this game.","requestId":"323e7f4a-6cf4-48b5-b8ba-64d4565edbc2"}}"#
