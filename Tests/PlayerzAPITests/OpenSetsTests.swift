import Foundation
import Testing

@testable import PlayerzAPI

/// The server's open sets of values (#34, projectZ#633): decoded as strings,
/// so a value added on the server never fails a response.
@Suite("Open sets of values")
struct OpenSetsTests {
    /// The vendored spec, as the generator reads it.
    private static func spec() throws -> [String: Any] {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/PlayerzAPI/openapi.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try #require(object as? [String: Any])
    }

    @Test("the app's sports are the server's known sports, in its order")
    func sportsMatchTheSpec() throws {
        let components = try #require(Self.spec()["components"] as? [String: Any])
        let schemas = try #require(components["schemas"] as? [String: Any])
        let sport = try #require(schemas["SportType"] as? [String: Any])
        #expect(sport["enum"] == nil)
        #expect(sport["x-known-values"] as? [String] == Sports.known)
    }

    @Test("the sports with a level are the server's, in its order")
    func leveledSportsMatchTheSpec() throws {
        let components = try #require(Self.spec()["components"] as? [String: Any])
        let schemas = try #require(components["schemas"] as? [String: Any])
        let sport = try #require(schemas["ProfileSport"] as? [String: Any])
        #expect(sport["x-known-values"] as? [String] == Sports.leveled)
    }

    @Test("a sport this build has never seen decodes")
    func anUnknownSportDecodes() async throws {
        let client = Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: ["listOpenGames": (200, UNKNOWN_SPORT)])
        )
        let page = try await client.listOpenGames(.init()).ok.body.json.data
        #expect(page.items.first?.sport == "SPIKEBALL")
        #expect(page.items.first?.resourceType == "NET")
    }
}

private let UNKNOWN_SPORT = #"{"data":{"items":[{"id":"g","sport":"SPIKEBALL","resourceType":"NET","courtName":"Court 1","venue":{"id":"v","slug":"v","name":"Venue","city":"Sofia"},"startTs":"2026-10-16T15:56:01.418Z","endTs":"2026-10-16T16:56:01.418Z","timezone":"Europe/Sofia","cutoffAt":"2026-10-15T15:56:01.418Z","capacity":4,"playersCount":1,"spotsLeft":2,"open":true,"levelMin":null,"levelMax":null,"note":null,"booker":{"firstName":"Иван","avatarUrl":null},"viewer":null}],"nextCursor":null}}"#
