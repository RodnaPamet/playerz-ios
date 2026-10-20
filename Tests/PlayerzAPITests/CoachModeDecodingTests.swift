import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for coach mode (playerz-ios#21), decoded through the
/// generated client.
///
/// Captured from the server's routes on the perf database, as the seeded coach
/// once approved and teaching at a Sofia venue:
/// - asking to teach at another venue, asking again, and withdrawing;
/// - terms refused for a length the venue's courts do not take and for a
///   negative rate, then saved; the whole week's hours;
/// - days off: none, a stretch added, one that ends before it starts;
/// - lessons: a played one marked a no-show, then again; an upcoming one, a
///   no-show refused before it starts, cancelled, then cancelled again.
@Suite("Coach mode decodes the server's JSON")
struct CoachModeDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func linksAndAskingToTeach() async throws {
        let links = try await client(["listMyCoachLinks": (200, LINKS)]).listMyCoachLinks().ok.body.json.data
        #expect(links.approved)
        let active = try #require(links.links.first { $0.status == .ACTIVE })
        #expect(active.lengthOptions == [60, 120, 180])
        #expect(active.hours.count == 7)
        #expect(active.hours.allSatisfy { TeachingHours.minutes($0.open) != nil && TeachingHours.minutes($0.close) != nil })
        let asked = try await client(["requestToTeach": (201, REQUESTED)])
            .requestToTeach(body: .json(.init(venueId: "v"))).created.body.json.data
        #expect(asked.links.contains { $0.status == .REQUESTED && $0.missing.isEmpty })
        let again = try await client(["requestToTeach": (409, EXISTS)]).requestToTeach(body: .json(.init(venueId: "v")))
        #expect(try again.conflict.body.json.error.code == "COACH_LINK_EXISTS")
        let withdrawn = try await client(["endMyCoachLink": (200, WITHDRAWN)])
            .endMyCoachLink(path: .init(id: "l")).ok.body.json.data
        #expect(withdrawn.links.contains { $0.status == .ENDED })
    }

    @Test func termsAndHours() async throws {
        let terms = Components.Schemas.SaveTeachingTermsRequest(hourlyRateCents: 4500, lessonMinutes: [60, 120])
        let saved = try await client(["saveMyTeachingTerms": (200, TERMS)])
            .saveMyTeachingTerms(path: .init(id: "l"), body: .json(terms)).ok.body.json.data
        #expect(saved.links.first { $0.status == .ACTIVE }?.hourlyRateCents == 4500)
        for (reply, field) in [(TERMS_LENGTH, "lessonMinutes"), (TERMS_BAD, "hourlyRateCents")] {
            let refused = try await client(["saveMyTeachingTerms": (400, reply)])
                .saveMyTeachingTerms(path: .init(id: "l"), body: .json(terms))
            let error = try refused.badRequest.body.json.error
            #expect(error.code == "VALIDATION_ERROR")
            // What the app names in its sentence for the field.
            #expect(error.details?.additionalProperties.value["field"] as? String == field)
        }
        let hours = try await client(["saveMyTeachingHours": (200, HOURS)])
            .saveMyTeachingHours(path: .init(id: "l"), body: .json(.init(hours: []))).ok.body.json.data
        #expect(hours.links.contains { $0.status == .ACTIVE && $0.missing.isEmpty })
    }

    @Test func daysOff() async throws {
        let none = try await client(["listMyCoachTimeOff": (200, OFF_NONE)]).listMyCoachTimeOff().ok.body.json.data
        #expect(none.items.isEmpty)
        let added = try await client(["addMyCoachTimeOff": (201, OFF_ADDED)])
            .addMyCoachTimeOff(body: .json(.init(startDate: "2026-11-09"))).created.body.json.data
        let off = try #require(added.items.first)
        #expect(off.startDate == "2026-11-09" && off.endDate == "2026-11-13")
        #expect(off.note == "Турнир в Пловдив")
        let bad = try await client(["addMyCoachTimeOff": (400, OFF_BAD)])
            .addMyCoachTimeOff(body: .json(.init(startDate: "2026-11-13")))
        #expect(try bad.badRequest.body.json.error.details?.additionalProperties.value["field"] as? String == "endDate")
    }

    @Test func lessons() async throws {
        let past = try await client(["listMyCoachLessons": (200, PAST)])
            .listMyCoachLessons(query: .init(when: .past)).ok.body.json.data
        let lesson = try #require(past.items.first)
        #expect(lesson.status == "COMPLETED")
        #expect(lesson.player?.name == "Георги Петров")
        #expect(lesson.players == 1)
        let marked = try await client(["markMyCoachLessonNoShow": (200, NO_SHOW)])
            .markMyCoachLessonNoShow(path: .init(id: "l")).ok.body.json.data
        #expect(marked.bookingId == lesson.bookingId)
        for (reply, reason) in [(NO_SHOW_AGAIN, "ALREADY_NO_SHOW"), (NO_SHOW_EARLY, "NOT_STARTED")] {
            let refused = try await client(["markMyCoachLessonNoShow": (409, reply)])
                .markMyCoachLessonNoShow(path: .init(id: "l"))
            let error = try refused.conflict.body.json.error
            #expect(error.code == "NO_SHOW_REFUSED")
            #expect(error.details?.additionalProperties.value["reason"] as? String == reason)
        }
        let cancelled = try await client(["cancelMyCoachLesson": (200, CANCELLED)])
            .cancelMyCoachLesson(path: .init(id: "l"), body: .json(.init(reason: "Болен съм."))).ok.body.json.data
        #expect(!cancelled.bookingId.isEmpty)
        let again = try await client(["cancelMyCoachLesson": (409, CANCEL_AGAIN)])
            .cancelMyCoachLesson(path: .init(id: "l"), body: .json(.init()))
        #expect(try again.conflict.body.json.error.code == "BOOKING_NOT_CANCELLABLE")
    }
}

private let LINKS = #"{"data":{"approved":true,"links":[{"id":"cmvgz2laa0001j0izwa4v25no","status":"ACTIVE","startedBy":"COACH","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"lengthOptions":[60,120,180],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90],"cancelCutoffHours":12,"hours":[{"dayOfWeek":0,"open":"08:00","close":"21:00"},{"dayOfWeek":1,"open":"08:00","close":"21:00"},{"dayOfWeek":2,"open":"08:00","close":"21:00"},{"dayOfWeek":3,"open":"08:00","close":"21:00"},{"dayOfWeek":4,"open":"08:00","close":"21:00"},{"dayOfWeek":5,"open":"08:00","close":"21:00"},{"dayOfWeek":6,"open":"08:00","close":"21:00"}],"missing":[],"createdAt":"2026-10-20T17:43:48Z","decidedAt":null,"endedAt":null}]}}"#
private let REQUESTED = #"{"data":{"approved":true,"links":[{"id":"cmvgzukc40022kbiz8gfk4jqt","status":"REQUESTED","startedBy":"COACH","club":{"name":"Plovdiv Tennis Center","slug":"plovdiv-tennis-center"},"venue":{"id":"cmvgybdkl0017jwizd8gqfktq","name":"Plovdiv Tennis Center","city":"Plovdiv","timezone":"Europe/Sofia"},"lengthOptions":[],"hourlyRateCents":null,"groupRateCents":null,"currency":"EUR","lessonMinutes":[],"cancelCutoffHours":24,"hours":[],"missing":[],"createdAt":"2026-10-20T18:05:33Z","decidedAt":null,"endedAt":null},{"id":"cmvgz2laa0001j0izwa4v25no","status":"ACTIVE","startedBy":"COACH","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"lengthOptions":[60,120,180],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90],"cancelCutoffHours":12,"hours":[{"dayOfWeek":0,"open":"08:00","close":"21:00"},{"dayOfWeek":1,"open":"08:00","close":"21:00"},{"dayOfWeek":2,"open":"08:00","close":"21:00"},{"dayOfWeek":3,"open":"08:00","close":"21:00"},{"dayOfWeek":4,"open":"08:00","close":"21:00"},{"dayOfWeek":5,"open":"08:00","close":"21:00"},{"dayOfWeek":6,"open":"08:00","close":"21:00"}],"missing":[],"createdAt":"2026-10-20T17:43:48Z","decidedAt":null,"endedAt":null}]}}"#
private let EXISTS = #"{"error":{"code":"COACH_LINK_EXISTS","message":"There is already a REQUESTED link between this coach and this venue.","requestId":"a8b2bdff-d7c8-453a-92e2-040a9ed5c573","details":{"status":"REQUESTED"}}}"#
private let TERMS = #"{"data":{"approved":true,"links":[{"id":"cmvgzukc40022kbiz8gfk4jqt","status":"ENDED","startedBy":"COACH","club":{"name":"Plovdiv Tennis Center","slug":"plovdiv-tennis-center"},"venue":{"id":"cmvgybdkl0017jwizd8gqfktq","name":"Plovdiv Tennis Center","city":"Plovdiv","timezone":"Europe/Sofia"},"lengthOptions":[],"hourlyRateCents":null,"groupRateCents":null,"currency":"EUR","lessonMinutes":[],"cancelCutoffHours":24,"hours":[],"missing":[],"createdAt":"2026-10-20T18:05:33Z","decidedAt":null,"endedAt":"2026-10-20T18:05:34Z"},{"id":"cmvgz2laa0001j0izwa4v25no","status":"ACTIVE","startedBy":"COACH","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"lengthOptions":[60,120,180],"hourlyRateCents":4500,"groupRateCents":null,"currency":"EUR","lessonMinutes":[60,120],"cancelCutoffHours":12,"hours":[{"dayOfWeek":0,"open":"08:00","close":"21:00"},{"dayOfWeek":1,"open":"08:00","close":"21:00"},{"dayOfWeek":2,"open":"08:00","close":"21:00"},{"dayOfWeek":3,"open":"08:00","close":"21:00"},{"dayOfWeek":4,"open":"08:00","close":"21:00"},{"dayOfWeek":5,"open":"08:00","close":"21:00"},{"dayOfWeek":6,"open":"08:00","close":"21:00"}],"missing":[],"createdAt":"2026-10-20T17:43:48Z","decidedAt":null,"endedAt":null}]}}"#
private let TERMS_LENGTH = #"{"error":{"code":"VALIDATION_ERROR","message":"lessonMinutes: NOT_A_COURT_LENGTH","requestId":"67dcdb48-aa9c-46a8-b933-91aaa08eb6b0","details":{"field":"lessonMinutes","reason":"NOT_A_COURT_LENGTH"}}}"#
private let TERMS_BAD = #"{"error":{"code":"VALIDATION_ERROR","message":"hourlyRateCents: OUT_OF_RANGE","requestId":"d71c455c-9d6e-408e-81f1-e412b62f48f0","details":{"field":"hourlyRateCents","reason":"OUT_OF_RANGE"}}}"#
private let HOURS = #"{"data":{"approved":true,"links":[{"id":"cmvgzukc40022kbiz8gfk4jqt","status":"REQUESTED","startedBy":"COACH","club":{"name":"Plovdiv Tennis Center","slug":"plovdiv-tennis-center"},"venue":{"id":"cmvgybdkl0017jwizd8gqfktq","name":"Plovdiv Tennis Center","city":"Plovdiv","timezone":"Europe/Sofia"},"lengthOptions":[],"hourlyRateCents":null,"groupRateCents":null,"currency":"EUR","lessonMinutes":[],"cancelCutoffHours":24,"hours":[],"missing":[],"createdAt":"2026-10-20T18:05:33Z","decidedAt":null,"endedAt":null},{"id":"cmvgz2laa0001j0izwa4v25no","status":"ACTIVE","startedBy":"COACH","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"lengthOptions":[60,120,180],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90],"cancelCutoffHours":12,"hours":[{"dayOfWeek":0,"open":"08:00","close":"21:00"},{"dayOfWeek":1,"open":"08:00","close":"21:00"},{"dayOfWeek":2,"open":"08:00","close":"21:00"},{"dayOfWeek":3,"open":"08:00","close":"21:00"},{"dayOfWeek":4,"open":"08:00","close":"21:00"},{"dayOfWeek":5,"open":"08:00","close":"21:00"},{"dayOfWeek":6,"open":"08:00","close":"21:00"}],"missing":[],"createdAt":"2026-10-20T17:43:48Z","decidedAt":null,"endedAt":null}]}}"#
private let WITHDRAWN = #"{"data":{"approved":true,"links":[{"id":"cmvgzukc40022kbiz8gfk4jqt","status":"ENDED","startedBy":"COACH","club":{"name":"Plovdiv Tennis Center","slug":"plovdiv-tennis-center"},"venue":{"id":"cmvgybdkl0017jwizd8gqfktq","name":"Plovdiv Tennis Center","city":"Plovdiv","timezone":"Europe/Sofia"},"lengthOptions":[],"hourlyRateCents":null,"groupRateCents":null,"currency":"EUR","lessonMinutes":[],"cancelCutoffHours":24,"hours":[],"missing":[],"createdAt":"2026-10-20T18:05:33Z","decidedAt":null,"endedAt":"2026-10-20T18:05:34Z"},{"id":"cmvgz2laa0001j0izwa4v25no","status":"ACTIVE","startedBy":"COACH","club":{"name":"Sofia Padel Club","slug":"sofia-padel-club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","timezone":"Europe/Sofia"},"lengthOptions":[60,120,180],"hourlyRateCents":4000,"groupRateCents":6000,"currency":"EUR","lessonMinutes":[60,90],"cancelCutoffHours":12,"hours":[{"dayOfWeek":0,"open":"08:00","close":"21:00"},{"dayOfWeek":1,"open":"08:00","close":"21:00"},{"dayOfWeek":2,"open":"08:00","close":"21:00"},{"dayOfWeek":3,"open":"08:00","close":"21:00"},{"dayOfWeek":4,"open":"08:00","close":"21:00"},{"dayOfWeek":5,"open":"08:00","close":"21:00"},{"dayOfWeek":6,"open":"08:00","close":"21:00"}],"missing":[],"createdAt":"2026-10-20T17:43:48Z","decidedAt":null,"endedAt":null}]}}"#
private let OFF_NONE = #"{"data":{"items":[]}}"#
private let OFF_ADDED = #"{"data":{"items":[{"id":"cmvgzukju002fkbiz84ktec1p","startDate":"2026-11-09","endDate":"2026-11-13","note":"Турнир в Пловдив"}]}}"#
private let OFF_BAD = #"{"error":{"code":"VALIDATION_ERROR","message":"endDate: ENDS_BEFORE_IT_STARTS","requestId":"65991340-c567-4973-ad6d-16f9853c0724","details":{"field":"endDate","reason":"ENDS_BEFORE_IT_STARTS"}}}"#
private let PAST = #"{"data":{"items":[{"id":"cmvgz3gmx0016kbizmtg9qd69","bookingId":"cmvgz3gmo0015kbizdwuyk780","status":"COMPLETED","startTs":"2026-10-19T15:00:00Z","endTs":"2026-10-19T16:00:00Z","venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","timezone":"Europe/Sofia"},"club":"Sofia Padel Club","court":{"name":"Court 3","sport":"PADEL"},"player":{"name":"Георги Петров","level":null,"rating":{"level":4.5,"provisional":true},"phone":null},"players":1,"coachFeeCents":4000,"currency":"EUR"}],"nextCursor":null}}"#
private let NO_SHOW = #"{"data":{"bookingId":"cmvgz3gmo0015kbizdwuyk780"}}"#
private let NO_SHOW_AGAIN = #"{"error":{"code":"NO_SHOW_REFUSED","message":"This booking is already marked as a no-show","requestId":"43abd39a-3621-488e-9d81-064408360843","details":{"reason":"ALREADY_NO_SHOW"}}}"#
private let NO_SHOW_EARLY = #"{"error":{"code":"NO_SHOW_REFUSED","message":"A booking cannot be a no-show before its start time","requestId":"aafa04cb-3c0c-4450-83bb-b619be0c829e","details":{"reason":"NOT_STARTED"}}}"#
private let CANCELLED = #"{"data":{"bookingId":"cmvgzuxxx002mkbiz6od0koyy"}}"#
private let CANCEL_AGAIN = #"{"error":{"code":"BOOKING_NOT_CANCELLABLE","message":"This booking is no longer cancellable: it was already cancelled, or its hold expired.","requestId":"25c4934a-b1dc-4fc2-acf1-950879866ac1"}}"#
