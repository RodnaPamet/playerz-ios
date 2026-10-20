import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Answers each operation with a status and body, and keeps what was asked.
private actor Replies: ClientTransport {
    private let replies: [String: (Int, String)]
    private(set) var operations: [String] = []
    private(set) var requests: [String: HTTPRequest] = [:]

    init(_ replies: [String: (Int, String)]) { self.replies = replies }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        operations.append(operationID)
        requests[operationID] = request
        guard let (status, json) = replies[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(status: .init(code: status), headerFields: [.contentType: "application/json"]),
            status == 204 ? nil : HTTPBody(json)
        )
    }

    func asked() -> [String] { operations }
    func request(_ operationID: String) -> HTTPRequest? { requests[operationID] }
}

private let SIGNED_IN = """
    {"data":{"tokenType":"Bearer","accessToken":"access-1","expiresAt":"2030-01-01T00:00:00Z",
    "expiresIn":900,"refreshToken":"r1","refreshExpiresAt":"2030-02-01T00:00:00Z"}}
    """

private func signedIn(_ replies: [String: (Int, String)]) async throws -> (PlayerzSession, Replies) {
    var all = replies
    all["authSignIn"] = (200, SIGNED_IN)
    let transport = Replies(all)
    let session = PlayerzSession(
        baseURL: URL(string: "https://playerz.test")!,
        persistence: MemoryPersistence(),
        transport: transport
    )
    try await session.signIn(email: "ivan@playerz.test", password: "pw")
    return (session, transport)
}

private func refusal(_ code: String, details: String? = nil) -> String {
    #"{"error":{"code":"\#(code)","message":"no"\#(details.map { ",\"details\":\($0)" } ?? "")}}"#
}

@Suite("Deleting the account and downloading its data (playerz-ios#9)")
struct AccountDeletionTests {
    @Test func aDeletedAccountIsSignedOutWithoutAskingTheServerAgain() async throws {
        let (session, transport) = try await signedIn(["deleteMe": (204, "")])

        #expect(await session.deleteAccount() == .deleted)
        #expect(await session.isSignedIn == false)
        // The server ended every session itself; a logout would only 401.
        #expect(await transport.asked() == ["authSignIn", "deleteMe"])
    }

    @Test func upcomingBookingsSayWhatToDoWithEach() async throws {
        let details = """
            {"total":27,"lessons":1,"tournaments":2,"bookings":[
             {"bookingId":"b1","role":"BOOKER","cure":"cancel","startTs":"2026-10-21T15:00:00.000Z",
              "endTs":"2026-10-21T16:00:00.000Z","cancellableUntil":"2026-10-21T13:00:00.000Z","deletableFrom":null},
             {"bookingId":"b2","role":"PARTICIPANT","cure":"wait","startTs":"2026-10-20T15:00:00Z",
              "endTs":"2026-10-20T16:30:00Z","cancellableUntil":null,"deletableFrom":"2026-10-20T16:30:00Z"}]}
            """
        let (session, _) = try await signedIn(["deleteMe": (409, refusal("UPCOMING_BOOKINGS", details: details))])

        guard case let .blocked(standing) = await session.deleteAccount() else {
            Issue.record("expected the account to be blocked")
            return
        }
        #expect(standing.total == 27)
        #expect(standing.lessons == 1)
        #expect(standing.tournaments == 2)
        #expect(standing.bookings.map(\.cure) == ["cancel", "wait"])
        #expect(standing.bookings[0].cancellableUntil == ISO8601DateFormatter().date(from: "2026-10-21T13:00:00Z"))
        #expect(standing.bookings[1].deletableFrom == standing.bookings[1].end)
        #expect(await session.isSignedIn, "a refusal changes nothing")
    }

    /// The perf server's own answer for its seeded player (projectZ, 2026-10-20).
    @Test func theServersOwnRefusalDecodes() async throws {
        let (session, _) = try await signedIn(["deleteMe": (409, CAPTURED_409)])
        guard case let .blocked(standing) = await session.deleteAccount() else {
            Issue.record("expected the account to be blocked")
            return
        }
        #expect(standing.total == 5 && standing.bookings.count == 5)
        #expect(standing.bookings.allSatisfy { $0.role == "BOOKER" && $0.cure == "cancel" })
        #expect(standing.bookings.allSatisfy { $0.cancellableUntil != nil && $0.start < $0.end })
    }

    @Test func aRefusalWhoseDetailsAreNotTheDocumentedShapeIsAFailureNotAnEmptyList() async throws {
        let (session, _) = try await signedIn(["deleteMe": (409, refusal("UPCOMING_BOOKINGS", details: #"{"x":1}"#))])
        #expect(await session.deleteAccount() == .failed)
    }

    /// Every refusal but `UPCOMING_BOOKINGS`: named by what it means, and nothing deleted.
    @Test(arguments: [
        (403, "CLUB_ACCOUNT_DELETION_BY_REQUEST", AccountDeletion.clubAccount),
        (403, "FORBIDDEN", .failed),
        (429, "RATE_LIMITED", .rateLimited),
        (500, "INTERNAL", .failed),
    ])
    func aRefusalDeletesNothing(status: Int, code: String, expected: AccountDeletion) async throws {
        let (session, _) = try await signedIn(["deleteMe": (status, refusal(code))])
        #expect(await session.deleteAccount() == expected)
        #expect(await session.isSignedIn, "a refusal changes nothing")
    }

    @Test func theExportIsTheServersBytesWithAFieldTheSpecDoesNotKnow() async throws {
        let file = #"{"version":8,"profile":{"name":"Иван"},"somethingNew":{"kept":true}}"#
        let (session, transport) = try await signedIn(["exportMyData": (200, file)])

        let data = try await session.exportData()

        #expect(String(decoding: data, as: UTF8.self) == file)
        let request = try #require(await transport.request("exportMyData"))
        #expect(request.path == "/me/export")
        #expect(request.headerFields[.authorization] == "Bearer access-1")
    }

    @Test func anExportRefusedForTooManyAttemptsSaysSo() async throws {
        let (session, _) = try await signedIn(["exportMyData": (429, refusal("RATE_LIMITED"))])
        await #expect(throws: DataExportError.rateLimited) { _ = try await session.exportData() }
    }
}

private let CAPTURED_409 = #"""
{"error":{"code":"UPCOMING_BOOKINGS","message":"The account still has 5 upcoming booking(s), 0 lesson(s) to teach and 0 tournament entr(y/ies). Cancel them, leave the ones you were added to, withdraw from the tournaments, and try again.","requestId":"d0aaf648-f081-47a7-b38a-0f469b0ffb46","details":{"total":5,"lessons":0,"tournaments":0,"bookings":[{"bookingId":"cmvgq4l1g00d2uiizabvd51is","role":"BOOKER","cure":"cancel","startTs":"2026-10-22T16:00:00.000Z","endTs":"2026-10-22T17:30:00.000Z","cancellableUntil":"2026-10-21T16:00:00.000Z","deletableFrom":"2026-10-22T17:30:00.000Z"},{"bookingId":"cmvgq4l1i00dduiiz5tnl7fle","role":"BOOKER","cure":"cancel","startTs":"2026-10-24T07:00:00.000Z","endTs":"2026-10-24T08:00:00.000Z","cancellableUntil":"2026-10-23T07:00:00.000Z","deletableFrom":"2026-10-24T08:00:00.000Z"},{"bookingId":"cmvgq4l1g00d3uiizo6kh475o","role":"BOOKER","cure":"cancel","startTs":"2026-10-26T18:00:00.000Z","endTs":"2026-10-26T19:30:00.000Z","cancellableUntil":"2026-10-25T18:00:00.000Z","deletableFrom":"2026-10-26T19:30:00.000Z"},{"bookingId":"cmvgq4l1g00d4uiiz66mg1vh9","role":"BOOKER","cure":"cancel","startTs":"2026-10-29T16:30:00.000Z","endTs":"2026-10-29T18:00:00.000Z","cancellableUntil":"2026-10-28T16:30:00.000Z","deletableFrom":"2026-10-29T18:00:00.000Z"},{"bookingId":"cmvgq4l1i00deuiize35h8rm2","role":"BOOKER","cure":"cancel","startTs":"2026-10-31T09:00:00.000Z","endTs":"2026-10-31T10:00:00.000Z","cancellableUntil":"2026-10-30T09:00:00.000Z","deletableFrom":"2026-10-31T10:00:00.000Z"}]}}}
"""#
