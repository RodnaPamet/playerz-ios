import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for a coach's own profile (playerz-ios#20), decoded
/// through the generated client.
///
/// Captured from the server's routes on the perf database: a new coach account
/// with no profile; a first save; sending it incomplete; a certificate
/// uploaded as multipart (a PNG) and an empty one refused; the profile made
/// whole and sent; a change refused while it waits; taking it back, and again;
/// the certificate removed. Also the approved seeded coach, and a player
/// asking (refused).
@Suite("A coach's profile decodes the server's JSON")
struct CoachProfileDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func notStartedThenADraft() async throws {
        let none = try await client(["getMyCoachProfile": (200, NONE)]).getMyCoachProfile().ok.body.json.data
        #expect(none.state == .NONE && none.slug == nil && none.certificate == nil)
        #expect(Set(none.missing) == [.bio, .sports, .certificate])
        #expect(none.canEdit.text && none.canEdit.certificate)
        let draft = try await client(["saveMyCoachProfile": (200, DRAFT)])
            .saveMyCoachProfile(body: .json(.init(bio: "Кратко."))).ok.body.json.data
        #expect(draft.state == .DRAFT && draft.slug == "martina-koleva")
        #expect(draft.sports.first?.levelMax == 5)
        // Under 40 characters: the bio still counts as missing.
        #expect(draft.missing.contains(.bio))
    }

    @Test func theCertificate() async throws {
        let part = OpenAPIRuntime.MultipartPart(
            payload: Operations.uploadMyCoachCertificate.Input.Body.multipartFormPayload.filePayload(body: .init([0x89])),
            filename: "cert.png"
        )
        let uploaded = try await client(["uploadMyCoachCertificate": (200, CERTIFICATE)])
            .uploadMyCoachCertificate(body: .multipartForm([.file(part)])).ok.body.json.data
        let file = try #require(uploaded.certificate)
        #expect(file.mimeType == .image_sol_png)
        #expect(file.fileName == "cert.png")
        let empty = try await client(["uploadMyCoachCertificate": (400, CERTIFICATE_EMPTY)])
            .uploadMyCoachCertificate(body: .multipartForm([.file(part)]))
        let refused = try empty.badRequest.body.json.error
        #expect(refused.code == "CERTIFICATE_REFUSED")
        #expect(refused.details?.additionalProperties.value["reason"] as? String == "EMPTY")
        let removed = try await client(["removeMyCoachCertificate": (200, REMOVED)])
            .removeMyCoachCertificate().ok.body.json.data
        #expect(removed.certificate == nil)
    }

    @Test func sendingAndTakingBack() async throws {
        let incomplete = try await client(["submitMyCoachProfile": (409, INCOMPLETE)]).submitMyCoachProfile()
        #expect(try incomplete.conflict.body.json.error.code == "COACH_PROFILE_INCOMPLETE")
        let sent = try await client(["submitMyCoachProfile": (200, SUBMITTED)]).submitMyCoachProfile().ok.body.json.data
        #expect(sent.state == .SUBMITTED && sent.submittedAt != nil)
        #expect(!sent.canEdit.text && !sent.canEdit.certificate)
        #expect(sent.missing.isEmpty)
        let locked = try await client(["saveMyCoachProfile": (409, LOCKED)])
            .saveMyCoachProfile(body: .json(.init(bio: "x")))
        #expect(try locked.conflict.body.json.error.code == "COACH_PROFILE_LOCKED")
        let back = try await client(["withdrawMyCoachProfile": (200, WITHDRAWN)]).withdrawMyCoachProfile().ok.body.json.data
        #expect(back.state == .DRAFT && back.canEdit.text)
        let again = try await client(["withdrawMyCoachProfile": (409, NOT_SUBMITTED)]).withdrawMyCoachProfile()
        #expect(try again.conflict.body.json.error.code == "COACH_PROFILE_NOT_SUBMITTED")
    }

    @Test func approvedAndNotACoach() async throws {
        let approved = try await client(["getMyCoachProfile": (200, APPROVED)]).getMyCoachProfile().ok.body.json.data
        #expect(approved.state == .APPROVED)
        #expect(approved.canEdit.text && !approved.canEdit.certificate)
        let player = try await client(["getMyCoachProfile": (403, NOT_COACH)]).getMyCoachProfile()
        #expect(try player.forbidden.body.json.error.code == "COACH_ACCOUNT_REQUIRED")
    }
}

private let NONE = #"{"data":{"state":"NONE","slug":null,"bio":null,"qualifications":null,"sports":[],"certificate":null,"submittedAt":null,"decidedAt":null,"decisionNote":null,"missing":["bio","sports","certificate"],"canEdit":{"text":true,"certificate":true}}}"#
private let DRAFT = #"{"data":{"state":"DRAFT","slug":"martina-koleva","bio":"Кратко.","qualifications":null,"sports":[{"sport":"TENNIS","levelMin":2,"levelMax":5}],"certificate":null,"submittedAt":null,"decidedAt":null,"decisionNote":null,"missing":["bio","certificate"],"canEdit":{"text":true,"certificate":true}}}"#
private let APPROVED = #"{"data":{"state":"APPROVED","slug":"borislav-atanasov","bio":"Треньор по падел от 2015 г. Работя с начинаещи и с играчи за турнири.","qualifications":"Лиценз на Българската федерация по падел, ниво 2.","sports":[{"sport":"PADEL","levelMin":1,"levelMax":6}],"certificate":null,"submittedAt":null,"decidedAt":"2026-10-20T17:43:48Z","decisionNote":null,"missing":["certificate"],"canEdit":{"text":true,"certificate":false}}}"#
private let NOT_COACH = #"{"error":{"code":"COACH_ACCOUNT_REQUIRED","message":"This is for coach accounts.","requestId":"4c9d41ce-13fe-4a39-889c-85d978409f57"}}"#
private let INCOMPLETE = #"{"error":{"code":"COACH_PROFILE_INCOMPLETE","message":"The coach profile is missing: bio, certificate.","requestId":"a46cabb1-ba62-4554-a3fa-83540807c7a2","details":{"missing":["bio","certificate"]}}}"#
private let CERTIFICATE = #"{"data":{"state":"DRAFT","slug":"martina-koleva","bio":"Кратко.","qualifications":null,"sports":[{"sport":"TENNIS","levelMin":2,"levelMax":5}],"certificate":{"fileName":"cert.png","mimeType":"image/png","byteSize":70,"uploadedAt":"2026-10-20T17:55:28Z"},"submittedAt":null,"decidedAt":null,"decisionNote":null,"missing":["bio"],"canEdit":{"text":true,"certificate":true}}}"#
private let CERTIFICATE_EMPTY = #"{"error":{"code":"CERTIFICATE_REFUSED","message":"Upload a PDF, or a JPEG, PNG or WebP image, of 5 MB at most.","requestId":"006e8b0a-d0bc-47c4-b9a2-8c99ee4b4117","details":{"reason":"EMPTY"}}}"#
private let SUBMITTED = #"{"data":{"state":"SUBMITTED","slug":"martina-koleva","bio":"Треньор по тенис от 2012 г. Работя с деца и възрастни, от първия удар до турнири.","qualifications":"Лиценз на БФТ.","sports":[{"sport":"TENNIS","levelMin":1,"levelMax":5}],"certificate":{"fileName":"cert.png","mimeType":"image/png","byteSize":70,"uploadedAt":"2026-10-20T17:55:28Z"},"submittedAt":"2026-10-20T17:55:28Z","decidedAt":null,"decisionNote":null,"missing":[],"canEdit":{"text":false,"certificate":false}}}"#
private let LOCKED = #"{"error":{"code":"COACH_PROFILE_LOCKED","message":"The coach profile cannot be changed while it is SUBMITTED.","requestId":"d6a650c9-dab1-4672-ad50-974a0bbf00bc","details":{"state":"SUBMITTED"}}}"#
private let WITHDRAWN = #"{"data":{"state":"DRAFT","slug":"martina-koleva","bio":"Треньор по тенис от 2012 г. Работя с деца и възрастни, от първия удар до турнири.","qualifications":"Лиценз на БФТ.","sports":[{"sport":"TENNIS","levelMin":1,"levelMax":5}],"certificate":{"fileName":"cert.png","mimeType":"image/png","byteSize":70,"uploadedAt":"2026-10-20T17:55:28Z"},"submittedAt":null,"decidedAt":null,"decisionNote":null,"missing":[],"canEdit":{"text":true,"certificate":true}}}"#
private let NOT_SUBMITTED = #"{"error":{"code":"COACH_PROFILE_NOT_SUBMITTED","message":"The coach profile is not waiting for a decision.","requestId":"fa339408-b023-4688-83f6-2a24c364e77d"}}"#
private let REMOVED = #"{"data":{"state":"DRAFT","slug":"martina-koleva","bio":"Треньор по тенис от 2012 г. Работя с деца и възрастни, от първия удар до турнири.","qualifications":"Лиценз на БФТ.","sports":[{"sport":"TENNIS","levelMin":1,"levelMax":5}],"certificate":null,"submittedAt":null,"decidedAt":null,"decisionNote":null,"missing":["certificate"],"canEdit":{"text":true,"certificate":true}}}"#
