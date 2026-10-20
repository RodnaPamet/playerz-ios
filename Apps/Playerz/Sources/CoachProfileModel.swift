import Foundation
import Observation
import OpenAPIRuntime
import PlayerzAPI

/// «Профил на треньор» (playerz-ios#20), the web's `/me/coach`: the profile as
/// the server holds it, the text and sports being edited, and the writes.
/// Every write answers the whole profile, which replaces what is shown.
@MainActor
@Observable
final class CoachProfileModel {
    static let bioMin = 40
    static let textMax = 1000
    static let certificateMaxBytes = 5 * 1024 * 1024
    static let keptDays = 30

    private(set) var profile: Components.Schemas.MyCoachProfile?
    var bio = ""
    var qualifications = ""
    var sports: [Components.Schemas.CoachSportLevels] = []
    private(set) var busy = false
    private(set) var failed = false
    /// What the last write did, or why it did not.
    private(set) var line: (text: String, isError: Bool)?

    /// Whether the text and sports differ from what is stored.
    var edited: Bool {
        guard let profile else { return false }
        return bio != (profile.bio ?? "") || qualifications != (profile.qualifications ?? "") || sports != profile.sports
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            show(try await client.getMyCoachProfile().ok.body.json.data)
            failed = false
        } catch {
            failed = profile == nil
        }
    }

    func save(_ session: SessionModel) async {
        await write(saved: String(localized: "coachProfile.saved"), session) { client in
            let body = Components.Schemas.SaveCoachProfileRequest(
                bio: self.bio.isEmpty ? nil : self.bio,
                qualifications: self.qualifications.isEmpty ? nil : self.qualifications,
                sports: self.sports
            )
            let response = try await client.saveMyCoachProfile(body: .json(body))
            return (try? response.ok.body.json.data, response)
        }
    }

    func submit(_ session: SessionModel) async {
        // Unsaved text first: what is sent for approval is what is stored.
        if edited { await save(session) }
        await write(saved: String(localized: "coachProfile.submitted"), session) { client in
            let response = try await client.submitMyCoachProfile()
            return (try? response.ok.body.json.data, response)
        }
    }

    func withdraw(_ session: SessionModel) async {
        await write(saved: String(localized: "coachProfile.withdrawn"), session) { client in
            let response = try await client.withdrawMyCoachProfile()
            return (try? response.ok.body.json.data, response)
        }
    }

    /// A PDF or a photo, up to 5 MB; the server decides the type by its bytes.
    func upload(_ data: Data, fileName: String, _ session: SessionModel) async {
        guard !data.isEmpty else {
            line = (String(localized: "coachProfile.error.EMPTY"), true)
            return
        }
        guard data.count <= Self.certificateMaxBytes else {
            line = (String(localized: "coachProfile.error.TOO_LARGE \(5)"), true)
            return
        }
        await write(saved: String(localized: "coachProfile.saved"), session) { client in
            let part = OpenAPIRuntime.MultipartPart(
                payload: Operations.uploadMyCoachCertificate.Input.Body.multipartFormPayload.filePayload(body: .init(data)),
                filename: fileName
            )
            let response = try await client.uploadMyCoachCertificate(body: .multipartForm([.file(part)]))
            return (try? response.ok.body.json.data, response)
        }
    }

    func removeCertificate(_ session: SessionModel) async {
        await write(saved: String(localized: "coachProfile.saved"), session) { client in
            let response = try await client.removeMyCoachCertificate()
            return (try? response.ok.body.json.data, response)
        }
    }

    private func write(
        saved: String,
        _ session: SessionModel,
        _ call: (Client) async throws -> (Components.Schemas.MyCoachProfile?, Any)
    ) async {
        guard let client = await session.client() else { return }
        busy = true
        defer { busy = false }
        do {
            let (fresh, response) = try await call(client)
            if let fresh {
                show(fresh)
                line = (saved, false)
            } else {
                line = (Self.error(apiError(response)), true)
            }
        } catch {
            line = (String(localized: "coachProfile.error.NETWORK"), true)
        }
    }

    private func show(_ fresh: Components.Schemas.MyCoachProfile) {
        profile = fresh
        bio = fresh.bio ?? ""
        qualifications = fresh.qualifications ?? ""
        sports = fresh.sports
    }

    private static func error(_ error: Components.Schemas._Error.errorPayload?) -> String {
        switch error?.code {
        case "COACH_PROFILE_LOCKED", "COACH_PROFILE_INCOMPLETE", "COACH_PROFILE_NOT_SUBMITTED", "VALIDATION_ERROR", "RATE_LIMITED":
            return localized(key: "coachProfile.error.\(error?.code ?? "")")
        case "CERTIFICATE_REFUSED":
            switch error?.details?.additionalProperties.value["reason"] as? String {
            case "EMPTY": return String(localized: "coachProfile.error.EMPTY")
            case "TOO_LARGE": return String(localized: "coachProfile.error.TOO_LARGE \(5)")
            default: return String(localized: "coachProfile.error.NOT_A_CERTIFICATE")
            }
        default:
            return String(localized: "coachProfile.error.UNKNOWN")
        }
    }
}
