import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// What deleting the account would meet, read before asking (projectZ#628),
/// from `GET /me/deletion` captured on the perf database: the seeded player
/// (upcoming bookings), the club's owner (a club account), and a player with
/// nothing ahead and 12.50 € of credit at one club.
@Suite("The deletion check decodes the server's JSON")
struct DeletionCheckTests {
    private static let SIGNED_IN = #"{"data":{"tokenType":"Bearer","accessToken":"a","expiresAt":"2030-01-01T00:00:00Z","expiresIn":900,"refreshToken":"r","refreshExpiresAt":"2030-02-01T00:00:00Z"}}"#

    private func check(_ reply: (Int, String)) async throws -> DeletionCheck? {
        let session = PlayerzSession(
            baseURL: URL(string: "https://playerz.test")!,
            persistence: MemoryPersistence(),
            transport: Canned(replies: ["authSignIn": (200, Self.SIGNED_IN), "getMyDeletionStanding": reply])
        )
        try await session.signIn(email: "ivan@playerz.test", password: "pw")
        return await session.deletionCheck()
    }

    @Test func blockedByUpcomingBookings() async throws {
        let check = try #require(try await check((200, BLOCKED)))
        guard case let .blocked(standing)? = check.refusal else {
            Issue.record("expected blocked, got \(String(describing: check.refusal))")
            return
        }
        #expect(standing.total == 5 && standing.bookings.count == 5)
        #expect(standing.bookings.allSatisfy { $0.role == "BOOKER" && $0.deletableFrom != nil })
        #expect(check.credit.isEmpty)
    }

    @Test func aClubAccount() async throws {
        let check = try #require(try await check((200, CLUB)))
        #expect(check.refusal == .clubAccount)
    }

    @Test func allowedWithCreditItLoses() async throws {
        let check = try #require(try await check((200, CREDIT)))
        #expect(check.refusal == nil)
        #expect(check.credit == [.init(club: "Sofia Padel Club", amountCents: 1250, currency: "EUR")])
    }

    @Test func unreadableIsUnknownNotAllowed() async throws {
        // The section then states the rule, and DELETE /me still decides.
        #expect(try await check((500, #"{"error":{"code":"INTERNAL","message":"x"}}"#)) == nil)
    }
}

private let BLOCKED = #"{"data":{"kind":"blocked","credit":[],"blocked":{"total":5,"lessons":0,"tournaments":0,"bookings":[{"bookingId":"cmvh0nmgp00d2hbizs53rqwnn","venueName":"Sofia Padel Club","courtName":"Court 4","resourceType":"COURT","timezone":"Europe/Sofia","startTs":"2026-10-22T16:00:00Z","endTs":"2026-10-22T17:30:00Z","role":"BOOKER","cure":"cancel","cancellableUntil":"2026-10-21T16:00:00Z","deletableFrom":"2026-10-22T17:30:00Z"},{"bookingId":"cmvh0nmgp00ddhbizdarwkykg","venueName":"Plovdiv Tennis Center","courtName":"Court 3","resourceType":"COURT","timezone":"Europe/Sofia","startTs":"2026-10-24T07:00:00Z","endTs":"2026-10-24T08:00:00Z","role":"BOOKER","cure":"cancel","cancellableUntil":"2026-10-23T07:00:00Z","deletableFrom":"2026-10-24T08:00:00Z"},{"bookingId":"cmvh0nmgp00d3hbizjbnow83r","venueName":"Sofia Padel Club","courtName":"Court 1","resourceType":"COURT","timezone":"Europe/Sofia","startTs":"2026-10-26T18:00:00Z","endTs":"2026-10-26T19:30:00Z","role":"BOOKER","cure":"cancel","cancellableUntil":"2026-10-25T18:00:00Z","deletableFrom":"2026-10-26T19:30:00Z"},{"bookingId":"cmvh0nmgp00d4hbizs9fph43k","venueName":"Sofia Padel Club","courtName":"Court 2","resourceType":"COURT","timezone":"Europe/Sofia","startTs":"2026-10-29T16:30:00Z","endTs":"2026-10-29T18:00:00Z","role":"BOOKER","cure":"cancel","cancellableUntil":"2026-10-28T16:30:00Z","deletableFrom":"2026-10-29T18:00:00Z"},{"bookingId":"cmvh0nmgp00dehbizcjk4pcwi","venueName":"Plovdiv Tennis Center","courtName":"Court 4","resourceType":"COURT","timezone":"Europe/Sofia","startTs":"2026-10-31T09:00:00Z","endTs":"2026-10-31T10:00:00Z","role":"BOOKER","cure":"cancel","cancellableUntil":"2026-10-30T09:00:00Z","deletableFrom":"2026-10-31T10:00:00Z"}]}}}"#
private let CLUB = #"{"data":{"kind":"club","credit":[],"blocked":null}}"#
private let CREDIT = #"{"data":{"kind":"allowed","credit":[{"club":"Sofia Padel Club","amountCents":1250,"currency":"EUR"}],"blocked":null}}"#
