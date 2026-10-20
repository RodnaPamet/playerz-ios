import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for the bell (playerz-ios#15), decoded through the
/// generated client.
///
/// Captured from the server's routes on the perf database, after the server's
/// own flows wrote them: a club cancelled one of the player's bookings, and a
/// player left the player's game and joined again through an invite link.
/// Then marking one read, and an id that is not the caller's.
@Suite("The bell decodes the server's JSON")
struct NotificationsDecodingTests {
    private static let replies: [String: (Int, String)] = [
        "listMyNotifications": (200, PAGE),
        "markMyNotificationsRead": (200, MARKED),
    ]

    private func client(_ override: [String: (Int, String)] = [:]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: Self.replies.merging(override) { _, new in new })
        )
    }

    @Test func thePageAndItsCount() async throws {
        let page = try await client().listMyNotifications().ok.body.json.data
        #expect(page.unreadCount == 3)
        #expect(page.nextCursor == nil)
        #expect(page.items.map(\.kind) == ["BOOKING_CANCELLED", "BOOKING_PLAYER_JOINED", "BOOKING_PLAYER_LEFT"])
        let cancelled = try #require(page.items.first)
        #expect(cancelled.title == "Клубът отмени резервацията ви")
        #expect(!cancelled.read && cancelled.readAt == nil)
        // Each row names its screen.
        #expect(
            AppLink(href: cancelled.href, refType: cancelled.refType, refId: cancelled.refId)
                == .booking("cmvgwoetl00d4zbizvkec505a")
        )
    }

    @Test func aKindAddedLaterStillDecodes() async throws {
        let page = try await client(["listMyNotifications": (200, UNKNOWN_KIND)])
            .listMyNotifications().ok.body.json.data
        let row = try #require(page.items.first)
        #expect(row.kind == "COURT_RESURFACED")
        // No screen in the app for it: shown, and opens nothing.
        #expect(AppLink(href: row.href, refType: row.refType, refId: row.refId) == nil)
    }

    @Test func markingReadAnswersTheNewCount() async throws {
        let marked = try await client()
            .markMyNotificationsRead(body: .json(.case1(.init(ids: ["n"])))).ok.body.json.data
        #expect(marked.marked == 1)
        #expect(marked.unreadCount == 2)
    }

    @Test func anIdThatIsNotTheCallersIsRefused() async throws {
        let response = try await client(["markMyNotificationsRead": (404, NOT_FOUND)])
            .markMyNotificationsRead(body: .json(.case2(.init(all: true))))
        #expect(try response.notFound.body.json.error.code == "NOT_FOUND")
    }
}

private let PAGE = #"{"data":{"items":[{"id":"cmvgximq2000r2oizrk3x16qx","kind":"BOOKING_CANCELLED","title":"Клубът отмени резервацията ви","body":"Sofia Padel Club, Court 2 · чт, 29.10, 18:30–20:00","href":"/me/bookings/cmvgwoetl00d4zbizvkec505a","refType":"booking","refId":"cmvgwoetl00d4zbizvkec505a","read":false,"readAt":null,"createdAt":"2026-10-20T17:00:17.930Z"},{"id":"cmvgxihg0000n2oizgjxjdck2","kind":"BOOKING_PLAYER_JOINED","title":"Елена Иванова се включи в играта","body":"Sofia Padel Club · чт, 22.10, 19:00–20:30","href":"/me/bookings/cmvgwoetl00d2zbiz40qb8o1d","refType":"booking","refId":"cmvgwoetl00d2zbiz40qb8o1d","read":false,"readAt":null,"createdAt":"2026-10-20T17:00:11.088Z"},{"id":"cmvgxihef000k2oizrczrmg2z","kind":"BOOKING_PLAYER_LEFT","title":"Елена Иванова напусна играта","body":"Sofia Padel Club · чт, 22.10, 19:00–20:30","href":"/me/bookings/cmvgwoetl00d2zbiz40qb8o1d","refType":"booking","refId":"cmvgwoetl00d2zbiz40qb8o1d","read":false,"readAt":null,"createdAt":"2026-10-20T17:00:11.031Z"}],"nextCursor":null,"unreadCount":3}}"#
private let MARKED = #"{"data":{"marked":1,"unreadCount":2}}"#
private let NOT_FOUND = #"{"error":{"code":"NOT_FOUND","message":"Notification not found","requestId":"892474b9-0632-4209-9df4-1429d5b9ed4b"}}"#
private let UNKNOWN_KIND = #"{"data":{"items":[{"id":"cmvgximq2000r2oizrk3x00aa","kind":"COURT_RESURFACED","title":"Кортът е с нова настилка","body":"Sofia Padel Club","href":"/tournaments/t1","refType":null,"refId":null,"read":false,"readAt":null,"createdAt":"2026-10-20T17:00:17.930Z"}],"nextCursor":null,"unreadCount":3}}"#
