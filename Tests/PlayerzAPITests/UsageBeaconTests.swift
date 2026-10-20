import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Keeps what each beacon carried: its path, its body and any token.
private actor Beacons: ClientTransport {
    struct Sent: Equatable { let path: String?; let body: String; let token: String? }
    private(set) var sent: [Sent] = []
    private let status: Int

    init(status: Int = 204) { self.status = status }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if operationID == "authSignIn" {
            let tokens = #"{"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z","expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}"#
            return (HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), HTTPBody(tokens))
        }
        let text = body == nil ? "" : try await String(collecting: body!, upTo: 4096)
        sent.append(Sent(path: request.path, body: text, token: request.headerFields[.authorization]))
        return (HTTPResponse(status: .init(code: status)), nil)
    }

    func all() -> [Sent] { sent }
}

@Suite("The funnel beacon (playerz-ios#17)")
struct UsageBeaconTests {
    @Test(arguments: UsageBeacon.allCases)
    func eachEventGoesToItsVenueWithNoSession(_ event: UsageBeacon) async throws {
        let transport = Beacons()
        let session = PlayerzSession(baseURL: URL(string: "https://playerz.test")!, persistence: MemoryPersistence(), transport: transport)
        try await session.signIn(email: "ivan@playerz.test", password: "pw")

        await session.send(event, venueId: "v1")

        let sent = try #require(await transport.all().first)
        #expect(sent.path == "/venues/v1/usage-events")
        #expect(try JSONDecoder().decode([String: String].self, from: Data(sent.body.utf8)) == ["event": event.rawValue])
        #expect(sent.token == nil, "anonymous by construction, as the web sends it")
    }

    @Test func aFailedCountIsIgnored() async {
        let session = PlayerzSession(baseURL: URL(string: "https://playerz.test")!, persistence: MemoryPersistence(), transport: Beacons(status: 500))
        await session.send(.slotPicked, venueId: "v1")  // returns, never throws
    }
}
