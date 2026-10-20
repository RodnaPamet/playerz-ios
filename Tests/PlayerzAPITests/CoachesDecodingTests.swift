import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for coaches and lessons (playerz-ios#19), decoded
/// through the generated client.
///
/// Captured from the server's routes on the perf database, coaches on, with
/// its seeded coach approved and teaching at a Sofia venue:
/// - the list, the coach's page, the venue's coaches, and one day's lesson times;
/// - a lesson booked, then the same Idempotency-Key answering the same booking;
/// - a lesson refused for its price, and for the club's booking limit;
/// - the lesson played: the coach reviewed, a second review refused, the
///   reviews, reporting one's own refused, and the review deleted.
@Suite("Coaches decode the server's JSON")
struct CoachesDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func theListThePageAndAVenuesCoaches() async throws {
        let page = try await client(["listCoaches": (200, COACHES)]).listCoaches().ok.body.json.data
        let coach = try #require(page.items.first)
        #expect(page.nextCursor == nil)
        #expect(coach.slug == "borislav-atanasov")
        #expect(coach.sports.first?.sport == "PADEL")
        #expect(coach.fromRateCents == 4000)
        let venue = try #require(coach.venues.first)
        #expect(venue.lessonMinutes == [60, 90] && venue.groupRateCents == 6000)

        let one = try await client(["getCoach": (200, COACH)]).getCoach(path: .init(slug: "s")).ok.body.json.data
        #expect(one.qualifications != nil)
        let here = try await client(["listVenueCoaches": (200, VENUE_COACHES)])
            .listVenueCoaches(path: .init(id: "v")).ok.body.json.data
        #expect(here.items.count == 1)
    }

    @Test func aDaysTimes() async throws {
        let times = try await client(["listCoachLessonTimes": (200, TIMES)])
            .listCoachLessonTimes(path: .init(slug: "s"), query: .init(linkId: "l", date: "2026-10-22", minutes: 60))
            .ok.body.json.data
        #expect(times.coachFeeCents == 4000)
        // The stricter of the club's cutoff (24 h) and the coach's own (12 h).
        #expect(times.cancelCutoffHours == 24)
        let first = try #require(times.times.first)
        #expect(first.totalCents == times.coachFeeCents + first.courtPriceCents)
        #expect(first.endTs.timeIntervalSince(first.startTs) == 3600)
    }

    @Test func bookingAndTheSameKeyAgain() async throws {
        let request = Components.Schemas.BookLessonRequest(linkId: "l", startTs: .now, minutes: 60)
        let booked = try await client(["bookLesson": (201, BOOKED)])
            .bookLesson(path: .init(slug: "s"), headers: .init(Idempotency_hyphen_Key: "k"), body: .json(request))
            .created.body.json.data
        #expect(booked.value2.lesson.coachFeeCents == 4000)
        #expect(booked.value2.lesson.totalCents == booked.value2.lesson.coachFeeCents + booked.value2.lesson.courtPriceCents)
        let replayed = try await client(["bookLesson": (200, REPLAYED)])
            .bookLesson(path: .init(slug: "s"), headers: .init(Idempotency_hyphen_Key: "k"), body: .json(request))
            .ok.body.json.data
        #expect(replayed.value1.id == booked.value1.id)
    }

    @Test func refusals() async throws {
        let request = Components.Schemas.BookLessonRequest(linkId: "l", startTs: .now, minutes: 60)
        let price = try await client(["bookLesson": (409, PRICE_CHANGED)])
            .bookLesson(path: .init(slug: "s"), headers: .init(Idempotency_hyphen_Key: "k"), body: .json(request))
        let refused = try price.conflict.body.json.error
        #expect(refused.code == "LESSON_PRICE_CHANGED")
        #expect(refused.details?.additionalProperties.value["totalCents"] != nil)
        let limit = try await client(["bookLesson": (409, LIMIT)])
            .bookLesson(path: .init(slug: "s"), headers: .init(Idempotency_hyphen_Key: "k"), body: .json(request))
        #expect(try limit.conflict.body.json.error.code == "BOOKING_LIMIT_REACHED")
    }

    @Test func reviewingTheCoachAfterTheLesson() async throws {
        let before = try await client(["getMyBooking": (200, CAN_REVIEW)])
            .getMyBooking(path: .init(id: "b")).ok.body.json.data
        let lesson = try #require(before.lesson)
        #expect(lesson.canReview && lesson.myReview == nil)
        let review = try await client(["reviewMyLessonCoach": (201, REVIEWED)])
            .reviewMyLessonCoach(path: .init(id: "b"), body: .json(.init(rating: 5)))
            .created.body.json.data
        #expect(review.status == "PUBLISHED")
        let again = try await client(["reviewMyLessonCoach": (409, ALREADY)])
            .reviewMyLessonCoach(path: .init(id: "b"), body: .json(.init(rating: 4)))
        #expect(try again.conflict.body.json.error.code == "COACH_ALREADY_REVIEWED")
        let after = try await client(["getMyBooking": (200, DETAIL_REVIEWED)])
            .getMyBooking(path: .init(id: "b")).ok.body.json.data
        #expect(after.lesson?.myReview?.rating == 5)
        #expect(after.lesson?.canReview == false)
    }

    @Test func theReviews() async throws {
        let page = try await client(["listCoachReviews": (200, REVIEWS)])
            .listCoachReviews(path: .init(slug: "s")).ok.body.json.data
        let mine = try #require(page.items.first)
        #expect(mine.mine && mine.author == "Георги П.")
        #expect(page.rating.reviewCount == 1)
        let own = try await client(["reportCoachReview": (400, REPORT_OWN)])
            .reportCoachReview(path: .init(id: "r"), body: .json(.init(reason: .spam)))
        #expect(try own.badRequest.body.json.error.code == "REPORT_OWN_REVIEW")
        let gone = try await client(["listCoachReviews": (200, REVIEWS_AFTER)])
            .listCoachReviews(path: .init(slug: "s")).ok.body.json.data
        #expect(gone.items.isEmpty && gone.rating.reviewCount == 0)
    }
}

private let COACHES = #"{"data":{"items":[{"slug":"borislav-atanasov","name":"Борислав Атанасов","avatarUrl":null,"bio":"Треньор по падел от 2015 г. Работя с начинаещи и с играчи за турнири.","qualifications":"Лиценз на Българската федерация по падел, ниво 2.","sports":[{"sport":"PADEL","levelMin":1,"levelMax":6}],"fromRateCents":4000,"currency":"EUR","rating":{"avgRating":0,"reviewCount":0},"venues":[{"linkId":"cmvgz2laa0001j0izwa4v25no","venueId":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"sports":["PADEL"],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90]}]}],"nextCursor":null}}"#
private let COACH = #"{"data":{"slug":"borislav-atanasov","name":"Борислав Атанасов","avatarUrl":null,"bio":"Треньор по падел от 2015 г. Работя с начинаещи и с играчи за турнири.","qualifications":"Лиценз на Българската федерация по падел, ниво 2.","sports":[{"sport":"PADEL","levelMin":1,"levelMax":6}],"fromRateCents":4000,"currency":"EUR","rating":{"avgRating":0,"reviewCount":0},"venues":[{"linkId":"cmvgz2laa0001j0izwa4v25no","venueId":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"sports":["PADEL"],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90]}]}}"#
private let VENUE_COACHES = #"{"data":{"items":[{"slug":"borislav-atanasov","name":"Борислав Атанасов","avatarUrl":null,"bio":"Треньор по падел от 2015 г. Работя с начинаещи и с играчи за турнири.","qualifications":"Лиценз на Българската федерация по падел, ниво 2.","sports":[{"sport":"PADEL","levelMin":1,"levelMax":6}],"fromRateCents":4000,"currency":"EUR","rating":{"avgRating":0,"reviewCount":0},"venues":[{"linkId":"cmvgz2laa0001j0izwa4v25no","venueId":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"sports":["PADEL"],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90]}]}]}}"#
private let TIMES = #"{"data":{"linkId":"cmvgz2laa0001j0izwa4v25no","venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia"},"date":"2026-10-22","minutes":60,"currency":"EUR","coachFeeCents":4000,"groupFeeCents":6000,"cancelCutoffHours":24,"times":[{"startTs":"2026-10-22T06:00:00Z","endTs":"2026-10-22T07:00:00Z","sport":"PADEL","court":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3"},"courtPriceCents":1920,"totalCents":5920},{"startTs":"2026-10-22T07:00:00Z","endTs":"2026-10-22T08:00:00Z","sport":"PADEL","court":{"id":"cmvgybdk2000vjwizi7j5xap2","name":"Court 4"},"courtPriceCents":1920,"totalCents":5920},{"startTs":"2026-10-22T07:30:00Z","endTs":"2026-10-22T08:30:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":1920,"totalCents":5920},{"startTs":"2026-10-22T08:00:00Z","endTs":"2026-10-22T09:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":1920,"totalCents":5920},{"startTs":"2026-10-22T08:30:00Z","endTs":"2026-10-22T09:30:00Z","sport":"PADEL","court":{"id":"cmvgybdj50004jwiz32vy5pal","name":"Court 1"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T09:00:00Z","endTs":"2026-10-22T10:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T09:30:00Z","endTs":"2026-10-22T10:30:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T10:00:00Z","endTs":"2026-10-22T11:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T10:30:00Z","endTs":"2026-10-22T11:30:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T11:00:00Z","endTs":"2026-10-22T12:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T11:30:00Z","endTs":"2026-10-22T12:30:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T12:00:00Z","endTs":"2026-10-22T13:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T12:30:00Z","endTs":"2026-10-22T13:30:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T13:00:00Z","endTs":"2026-10-22T14:00:00Z","sport":"PADEL","court":{"id":"cmvgybdjm000djwizh2q6zfre","name":"Court 2"},"courtPriceCents":2400,"totalCents":6400},{"startTs":"2026-10-22T14:30:00Z","endTs":"2026-10-22T15:30:00Z","sport":"PADEL","court":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3"},"courtPriceCents":2400,"totalCents":6400}]}}"#
private let BOOKED = #"{"data":{"id":"cmvgz3gmo0015kbizdwuyk780","status":"CONFIRMED","startTs":"2026-10-22T06:00:00Z","endTs":"2026-10-22T07:00:00Z","totalCents":1920,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T17:44:29Z","cancellableUntil":"2026-10-21T06:00:00Z","resource":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3","sport":"PADEL","resourceType":"COURT"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia"},"lesson":{"id":"cmvgz3gmx0016kbizmtg9qd69","coach":{"slug":"borislav-atanasov","name":"Борислав Атанасов"},"minutes":60,"coachFeeCents":4000,"groupFeeCents":6000,"courtPriceCents":1920,"totalCents":5920,"currency":"EUR"}}}"#
private let REPLAYED = #"{"data":{"id":"cmvgz3gmo0015kbizdwuyk780","status":"CONFIRMED","startTs":"2026-10-22T06:00:00Z","endTs":"2026-10-22T07:00:00Z","totalCents":1920,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T17:44:29Z","cancellableUntil":"2026-10-21T06:00:00Z","resource":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3","sport":"PADEL","resourceType":"COURT"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia"},"lesson":{"id":"cmvgz3gmx0016kbizmtg9qd69","coach":{"slug":"borislav-atanasov","name":"Борислав Атанасов"},"minutes":60,"coachFeeCents":4000,"groupFeeCents":6000,"courtPriceCents":1920,"totalCents":5920,"currency":"EUR"}}}"#
private let PRICE_CHANGED = #"{"error":{"code":"LESSON_PRICE_CHANGED","message":"The price of that lesson has changed.","requestId":"068a177a-c1a8-4400-b192-d218a9d65346","details":{"totalCents":5920}}}"#
private let LIMIT = #"{"error":{"code":"BOOKING_LIMIT_REACHED","message":"Достигнахте лимита на този клуб за предстоящи онлайн резервации (лимит: 3, вашите: 3). Отменете някоя от тях или се свържете с клуба.","requestId":"2f0ade25-bb22-4f99-a33e-880e3d0404b5","details":{"limit":3,"upcoming":3}}}"#
private let CAN_REVIEW = #"{"data":{"id":"cmvgz3gmo0015kbizdwuyk780","status":"COMPLETED","startTs":"2026-10-19T15:00:00Z","endTs":"2026-10-19T16:00:00Z","totalCents":1920,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T17:44:29Z","cancellableUntil":null,"resource":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3","sport":"PADEL","resourceType":"COURT"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia","publicSlug":"sofia-padel-club","addressLine":"Sofia Center 1","city":"Sofia","lat":42.6977,"lng":23.3219,"phone":null},"lesson":{"id":"cmvgz3gmx0016kbizmtg9qd69","coach":{"slug":"borislav-atanasov","name":"Борислав Атанасов"},"coachFeeCents":4000,"groupFeeCents":6000,"courtPriceCents":1920,"totalCents":5920,"myReview":null,"canReview":true},"viewerRole":"BOOKER","clubSlug":"sofia-padel-club","venueReview":{"id":"cmvgybhl805bthwiz2n3khn9f","bookingId":"cmvgybejx00d0hwiz6s5cfh0f","rating":5,"status":"PUBLISHED"},"canReview":false,"payAtClub":true,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false}],"capacity":4,"spotsLeft":3,"playersOpen":false}}"#
private let REVIEWED = #"{"data":{"id":"cmvgz3pos001ekbiz7s3g6v98","bookingId":"cmvgz3gmo0015kbizdwuyk780","rating":5,"body":null,"status":"PUBLISHED","createdAt":"2026-10-20T17:44:41Z"}}"#
private let ALREADY = #"{"error":{"code":"COACH_ALREADY_REVIEWED","message":"You have already reviewed this coach.","requestId":"593de33c-a605-4cbc-a2a5-29a35c11096d"}}"#
private let DETAIL_REVIEWED = #"{"data":{"id":"cmvgz3gmo0015kbizdwuyk780","status":"COMPLETED","startTs":"2026-10-19T15:00:00Z","endTs":"2026-10-19T16:00:00Z","totalCents":1920,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T17:44:29Z","cancellableUntil":null,"resource":{"id":"cmvgybdju000mjwizhc5aa0ja","name":"Court 3","sport":"PADEL","resourceType":"COURT"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia","publicSlug":"sofia-padel-club","addressLine":"Sofia Center 1","city":"Sofia","lat":42.6977,"lng":23.3219,"phone":null},"lesson":{"id":"cmvgz3gmx0016kbizmtg9qd69","coach":{"slug":"borislav-atanasov","name":"Борислав Атанасов"},"coachFeeCents":4000,"groupFeeCents":6000,"courtPriceCents":1920,"totalCents":5920,"myReview":{"id":"cmvgz3pos001ekbiz7s3g6v98","rating":5,"status":"PUBLISHED"},"canReview":false},"viewerRole":"BOOKER","clubSlug":"sofia-padel-club","venueReview":{"id":"cmvgybhl805bthwiz2n3khn9f","bookingId":"cmvgybejx00d0hwiz6s5cfh0f","rating":5,"status":"PUBLISHED"},"canReview":false,"payAtClub":true,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false}],"capacity":4,"spotsLeft":3,"playersOpen":false}}"#
private let REVIEWS = #"{"data":{"rating":{"avgRating":4.1,"reviewCount":1},"items":[{"id":"cmvgz3pos001ekbiz7s3g6v98","rating":5,"body":null,"author":"Георги П.","createdAt":"2026-10-20T17:44:41Z","mine":true}],"nextCursor":null}}"#
private let REVIEWS_AFTER = #"{"data":{"rating":{"avgRating":0,"reviewCount":0},"items":[],"nextCursor":null}}"#
private let REPORT_OWN = #"{"error":{"code":"REPORT_OWN_REVIEW","message":"You cannot report your own review.","requestId":"4f56707f-5d6f-496c-ab54-7fdc77da4dcc"}}"#
