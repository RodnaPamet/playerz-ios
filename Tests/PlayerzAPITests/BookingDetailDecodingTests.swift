import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for a booking's detail (playerz-ios#14), decoded through
/// the generated client.
///
/// Captured from the server's route handlers on the perf database: the
/// player's upcoming booking with two players added, a completed one before
/// and after its venue review, an invite link (its token replaced: the server
/// shows a token once), the link's preview and its acceptance, and the
/// refusals the screens put into words.
@Suite("A booking's detail decodes the server's JSON")
struct BookingDetailDecodingTests {
    private static let replies: [String: (Int, String)] = [
        "getMyBooking": (200, DETAIL_UPCOMING),
        "listBookingParticipants": (200, PARTICIPANTS),
        "listBookingCoPlayers": (200, CO_PLAYERS),
        "createBookingInviteLink": (201, INVITE_LINK),
        "previewBookingInvite": (200, INVITE_PREVIEW),
        "acceptBookingInvite": (200, INVITE_ACCEPTED),
        "reviewBooking": (201, REVIEW),
        "leaveBooking": (409, BOOKER_CANNOT_LEAVE),
    ]

    private func client(_ override: [String: (Int, String)] = [:]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: Self.replies.merging(override) { _, new in new })
        )
    }

    @Test func anUpcomingBookingWithItsPlayers() async throws {
        let booking = try await client().getMyBooking(path: .init(id: "b")).ok.body.json.data
        #expect(booking.status == "CONFIRMED")
        #expect(booking.viewerRole == .BOOKER)
        #expect(booking.clubSlug == "sofia-padel-club")
        #expect(booking.payAtClub)
        #expect(booking.lesson == nil)
        #expect(booking.cancellableUntil != nil)
        #expect(booking.players.map(\.name) == ["Георги Петров", "Елена Иванова", "Димитър Петров"])
        #expect(booking.endTs.timeIntervalSince(booking.startTs) == 90 * 60)
    }

    @Test func aCompletedBookingBeforeAndAfterItsReview() async throws {
        let before = try await client(["getMyBooking": (200, DETAIL_COMPLETED)])
            .getMyBooking(path: .init(id: "b")).ok.body.json.data
        #expect(before.canReview)
        #expect(before.venueReview == nil)
        #expect(before.cancellableUntil == nil)
        #expect(before.venue.phone == nil)

        let review = try await client()
            .reviewBooking(path: .init(slug: "c", id: "b"), body: .json(.init(rating: 4))).created.body.json.data
        #expect(review.status == "PUBLISHED")

        let after = try await client(["getMyBooking": (200, DETAIL_REVIEWED)])
            .getMyBooking(path: .init(id: "b")).ok.body.json.data
        #expect(!after.canReview)
        #expect(after.venueReview?.rating == 4)
        #expect(after.venueReview?.status == "PUBLISHED")
    }

    @Test func theParticipantsAsTheBookerSeesThem() async throws {
        let standing = try await client().listBookingParticipants(path: .init(id: "b")).ok.body.json.data
        #expect(standing.viewerRole == .BOOKER)
        #expect(standing.playersOpen)
        #expect(standing.spotsLeft == 1)
        #expect(standing.liveInviteLinks == 1)
        let booker = try #require(standing.players.first)
        #expect(booker.isBooker && booker.isYou && booker.participantId == nil)
        // An added player has a participant id: what removing them takes.
        #expect(standing.players.dropFirst().allSatisfy { $0.participantId != nil && !$0.isBooker })
    }

    /// For another of the player's bookings: the list leaves out who is on it already.
    @Test func peopleTheBookerHasPlayedWith() async throws {
        let people = try await client().listBookingCoPlayers(path: .init(id: "b")).ok.body.json.data
        #expect(people.map(\.name) == ["Елена Иванова", "Димитър Петров"])
    }

    @Test func anInviteLinkItsPreviewAndJoining() async throws {
        let link = try await client().createBookingInviteLink(path: .init(id: "b")).created.body.json.data
        let url = try #require(URL(string: link.url))
        #expect(BookingInviteLink.token(in: url) == "TOKEN-AS-SHARED")

        let preview = try await client()
            .previewBookingInvite(body: .json(.init(token: "t"))).ok.body.json.data
        #expect(preview.bookerFirstName == "Георги")
        #expect(preview.venue.timezone == "Europe/Sofia")
        #expect(preview.spotsLeft == 1)
        #expect(preview.lesson == nil)

        // The booker opening their own link: harmless, and not a new join.
        let accepted = try await client()
            .acceptBookingInvite(body: .json(.init(token: "t"))).ok.body.json.data
        #expect(!accepted.joined)
    }

    @Test func refusalsCarryTheirCodes() async throws {
        let dead = try await client(["previewBookingInvite": (404, INVITE_DEAD)])
            .previewBookingInvite(body: .json(.init(token: "t")))
        #expect(try dead.notFound.body.json.error.code == "BOOKING_INVITE_NOT_USABLE")

        let again = try await client(["reviewBooking": (409, ALREADY_REVIEWED)])
            .reviewBooking(path: .init(slug: "c", id: "b"), body: .json(.init(rating: 4)))
        #expect(try again.conflict.body.json.error.code == "ALREADY_REVIEWED")

        let leaving = try await client().leaveBooking(path: .init(id: "b"))
        #expect(try leaving.conflict.body.json.error.code == "BOOKER_CANNOT_LEAVE")
    }
}

private let DETAIL_UPCOMING = #"{"data":{"id":"cmvgwoetl00d2zbiz40qb8o1d","status":"CONFIRMED","startTs":"2026-10-22T16:00:00Z","endTs":"2026-10-22T17:30:00Z","totalCents":4500,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T16:36:48Z","cancellableUntil":"2026-10-21T16:00:00Z","resource":{"id":"cmvgwodsk000v13izfpegof93","name":"Court 4","sport":"PADEL","resourceType":"COURT"},"venue":{"id":"cmvgwodq3000313iz9xzdxf76","name":"Sofia Padel Club","timezone":"Europe/Sofia","publicSlug":"sofia-padel-club","addressLine":"Sofia Center 1","city":"Sofia","lat":42.6977,"lng":23.3219,"phone":null},"lesson":null,"viewerRole":"BOOKER","clubSlug":"sofia-padel-club","venueReview":{"id":"cmvgwohrc05btzbizi912mcer","bookingId":"cmvgwoetl00d0zbiznklow5eg","rating":5,"status":"PUBLISHED"},"canReview":false,"payAtClub":true,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false},{"participantId":"cmvgwra2y0000g2izga3iacgu","name":"Елена Иванова","avatarUrl":null,"isBooker":false,"isYou":false,"registered":true,"deleted":false},{"participantId":"cmvgwra3z0001g2izdi9779mu","name":"Димитър Петров","avatarUrl":null,"isBooker":false,"isYou":false,"registered":true,"deleted":false}],"capacity":4,"spotsLeft":1,"playersOpen":true}}"#
private let DETAIL_COMPLETED = #"{"data":{"id":"cmvgwoetl00dbzbiz38g9h6ax","status":"COMPLETED","startTs":"2026-10-16T07:00:00Z","endTs":"2026-10-16T08:00:00Z","totalCents":2400,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T16:36:48Z","cancellableUntil":null,"resource":{"id":"cmvgwodta001813iztrtfj3jj","name":"Court 1","sport":"TENNIS","resourceType":"COURT"},"venue":{"id":"cmvgwodt5001713izmd9wp76s","name":"Plovdiv Tennis Center","timezone":"Europe/Sofia","publicSlug":"plovdiv-tennis-center","addressLine":"Plovdiv Center 1","city":"Plovdiv","lat":42.1354,"lng":24.7453,"phone":null},"lesson":null,"viewerRole":"BOOKER","clubSlug":"plovdiv-tennis-center","venueReview":null,"canReview":true,"payAtClub":true,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false}],"capacity":4,"spotsLeft":3,"playersOpen":false}}"#
private let DETAIL_REVIEWED = #"{"data":{"id":"cmvgwoetl00dbzbiz38g9h6ax","status":"COMPLETED","startTs":"2026-10-16T07:00:00Z","endTs":"2026-10-16T08:00:00Z","totalCents":2400,"currency":"EUR","expiresAt":null,"cancelledAt":null,"createdAt":"2026-10-20T16:36:48Z","cancellableUntil":null,"resource":{"id":"cmvgwodta001813iztrtfj3jj","name":"Court 1","sport":"TENNIS","resourceType":"COURT"},"venue":{"id":"cmvgwodt5001713izmd9wp76s","name":"Plovdiv Tennis Center","timezone":"Europe/Sofia","publicSlug":"plovdiv-tennis-center","addressLine":"Plovdiv Center 1","city":"Plovdiv","lat":42.1354,"lng":24.7453,"phone":null},"lesson":null,"viewerRole":"BOOKER","clubSlug":"plovdiv-tennis-center","venueReview":{"id":"cmvgwrpny00032oizi2qjbbo2","bookingId":"cmvgwoetl00dbzbiz38g9h6ax","rating":4,"status":"PUBLISHED"},"canReview":false,"payAtClub":true,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false}],"capacity":4,"spotsLeft":3,"playersOpen":false}}"#
private let PARTICIPANTS = #"{"data":{"viewerRole":"BOOKER","capacity":4,"spotsLeft":1,"playersOpen":true,"liveInviteLinks":1,"players":[{"participantId":null,"name":"Георги Петров","avatarUrl":null,"isBooker":true,"isYou":true,"registered":true,"deleted":false},{"participantId":"cmvgwra2y0000g2izga3iacgu","name":"Елена Иванова","avatarUrl":null,"isBooker":false,"isYou":false,"registered":true,"deleted":false},{"participantId":"cmvgwra3z0001g2izdi9779mu","name":"Димитър Петров","avatarUrl":null,"isBooker":false,"isYou":false,"registered":true,"deleted":false}]}}"#
private let CO_PLAYERS = #"{"data":[{"userId":"cmvgwoe5k003kzbiznbyqvvmj","name":"Елена Иванова","avatarUrl":null},{"userId":"cmvgwoe5o003lzbizz26qzrwu","name":"Димитър Петров","avatarUrl":null}]}"#
private let INVITE_LINK = #"{"data":{"id":"cmvgwqj6o00012oizhqdc1htw","token":"TOKEN-AS-SHARED","url":"http://localhost:3301/invite/booking/TOKEN-AS-SHARED","expiresAt":"2026-10-22T16:00:00Z"}}"#
private let INVITE_PREVIEW = #"{"data":{"venue":{"name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"resource":{"name":"Court 4","sport":"PADEL","resourceType":"COURT"},"startTs":"2026-10-22T16:00:00Z","endTs":"2026-10-22T17:30:00Z","bookerFirstName":"Георги","capacity":4,"spotsLeft":1,"lesson":null}}"#
private let INVITE_ACCEPTED = #"{"data":{"bookingId":"cmvgwoetl00d2zbiz40qb8o1d","joined":false}}"#
private let INVITE_DEAD = #"{"error":{"code":"BOOKING_INVITE_NOT_USABLE","message":"That invite link is not usable: it expired at the start of the game, was stopped by the booker, or the booking was cancelled. The cases are deliberately indistinguishable.","requestId":"a3a3f721-6c58-4a43-bbb6-fb342e91bdc9"}}"#
private let REVIEW = #"{"data":{"id":"cmvgwrpny00032oizi2qjbbo2","bookingId":"cmvgwoetl00dbzbiz38g9h6ax","venueId":"cmvgwodt5001713izmd9wp76s","rating":4,"body":null,"status":"PUBLISHED","createdAt":"2026-10-20T16:39:22Z"}}"#
private let ALREADY_REVIEWED = #"{"error":{"code":"ALREADY_REVIEWED","message":"You have already reviewed this venue.","requestId":"2f48f454-967b-4c02-8e04-5fcc2b0b7968"}}"#
private let BOOKER_CANNOT_LEAVE = #"{"error":{"code":"BOOKER_CANNOT_LEAVE","message":"The booker cannot leave their own booking; cancel it instead.","requestId":"9138ea50-d7a0-44de-a86c-6e7fa4c54879"}}"#
