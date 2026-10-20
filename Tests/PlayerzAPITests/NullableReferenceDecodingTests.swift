import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// "An X, or null" reaches the app (#6).
///
/// The server writes these as `oneOf: [{$ref: X}, {type: null}]`, which the
/// generator used to skip: the property was simply missing from the Swift
/// type, and the app could not read `landing.club` or a booking's lesson.
/// `scripts/spec_for_swift.py` rewrites them before generating. These bodies
/// are built from the spec's required fields, with each such value once
/// present and once null, and decoded through `Client` as the screens do.
@Suite("Nullable references decode")
struct NullableReferenceDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: replies)
        )
    }

    @Test func anUndecidedAccountNamesTheClubItLandsOn() async throws {
        let me = try await client(["getMe": (200, ME_UNDECIDED_WITH_CLUB)]).getMe().ok.body.json.data
        #expect(me.landing.reason == "undecided")
        #expect(me.landing.club?.slug == "maleeva-club")
        #expect(me.landing.club?.name == "Тенис клуб Малееви")
    }

    @Test func aPlayerLandsOnNoClub() async throws {
        let me = try await client(["getMe": (200, ME_PLAYER)]).getMe().ok.body.json.data
        #expect(me.landing.reason == "player")
        #expect(me.landing.club == nil)
    }

    @Test func aLessonBookingCarriesItsLesson() async throws {
        let page = try await client(["listMyBookings": (200, MY_BOOKINGS)])
            .listMyBookings(.init(query: .init(when: .upcoming))).ok.body.json.data
        let lesson = try #require(page.items.first?.lesson)
        #expect(lesson.coach.name == "Мария")
        #expect(lesson.coachFeeCents == 3000 && lesson.courtPriceCents == 1500)
        #expect(lesson.totalCents == page.items.first?.totalCents)
    }

    @Test func aCourtBookingHasNoLessonAndMayHaveAReview() async throws {
        let page = try await client(["listMyBookings": (200, MY_BOOKINGS)])
            .listMyBookings(.init(query: .init(when: .upcoming))).ok.body.json.data
        let court = try #require(page.items.last)
        #expect(court.lesson == nil)
        #expect(court.venueReview?.rating == 5)
        #expect(page.items.first?.venueReview == nil)
    }
}

private let ME_UNDECIDED_WITH_CLUB = """
    {"data": {"id": "u1", "name": "Иван", "email": "ivan@playerz.test", "avatarUrl": null, "locale": "bg",
      "sports": [], "accountKind": null,
      "landing": {"reason": "undecided", "club": {"slug": "maleeva-club", "name": "Тенис клуб Малееви", "role": "OWNER"}},
      "searchable": true, "phone": {"required": false, "verified": false, "number": null}, "ratingPublic": true}}
    """

private let ME_PLAYER = """
    {"data": {"id": "u2", "name": "Мария", "email": "maria@playerz.test", "avatarUrl": null, "locale": "bg",
      "sports": [], "accountKind": "PLAYER",
      "landing": {"reason": "player", "club": null},
      "searchable": true, "phone": {"required": false, "verified": true, "number": "+35988*****56"}, "ratingPublic": true}}
    """

private let MY_BOOKINGS = """
    {"data": {"nextCursor": null, "items": [
      {"id": "b1", "status": "CONFIRMED", "startTs": "2026-10-21T15:00:00.000Z", "endTs": "2026-10-21T16:00:00.000Z",
       "totalCents": 4500, "currency": "EUR", "expiresAt": null, "cancelledAt": null,
       "createdAt": "2026-10-20T08:00:00.000Z", "cancellableUntil": "2026-10-21T13:00:00.000Z",
       "resource": {"id": "c1", "name": "Корт 1", "sport": "TENNIS", "resourceType": "COURT"},
       "venue": {"id": "v1", "name": "ТК Левски – Борисова градина", "timezone": "Europe/Sofia"},
       "clubSlug": "tennis-club-levski", "venueReview": null, "canReview": false, "viewerRole": "BOOKER",
       "lesson": {"id": "l1", "coach": {"slug": "maria", "name": "Мария"}, "coachFeeCents": 3000,
                  "groupFeeCents": null, "courtPriceCents": 1500, "totalCents": 4500, "myReview": null,
                  "canReview": false}},
      {"id": "b2", "status": "CONFIRMED", "startTs": "2026-10-22T09:00:00.000Z", "endTs": "2026-10-22T10:00:00.000Z",
       "totalCents": 2000, "currency": "EUR", "expiresAt": null, "cancelledAt": null,
       "createdAt": "2026-10-20T08:05:00.000Z", "cancellableUntil": null,
       "resource": {"id": "c9", "name": "Корт за скуош", "sport": "SQUASH", "resourceType": "COURT"},
       "venue": {"id": "v4", "name": "Тенис клуб Малееви", "timezone": "Europe/Sofia"},
       "clubSlug": "maleeva-club",
       "venueReview": {"id": "r1", "bookingId": "b2", "rating": 5, "status": "PUBLISHED"},
       "canReview": false, "viewerRole": "BOOKER", "lesson": null}
    ]}}
    """
