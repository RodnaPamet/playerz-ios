import Foundation
import Observation
import PlayerzAPI

/// Where a coach teaches or asked to (playerz-ios#21), the web's «Клубове»:
/// each link to a venue, its terms and its weekly hours. Every write answers
/// the whole list (or the link), which replaces what is shown.
@MainActor
@Observable
final class CoachLinksModel {
    private(set) var links: [Components.Schemas.MyCoachLink] = []
    /// Whether the platform has approved the coach: only then may they ask a club.
    private(set) var approved = false
    private(set) var loaded = false
    private(set) var failed = false
    private(set) var busy = false
    var line: (text: String, isError: Bool)?

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            let fresh = try await client.listMyCoachLinks().ok.body.json.data
            links = fresh.links
            approved = fresh.approved
            loaded = true
            failed = false
        } catch {
            failed = !loaded
        }
    }

    /// Ask to teach at a venue; the club answers.
    func request(_ venueId: String, _ session: SessionModel) async -> Bool {
        await act(session) { client in
            let response = try await client.requestToTeach(body: .json(.init(venueId: venueId)))
            if case let .created(created) = response {
                let fresh = try created.body.json.data
                self.links = fresh.links
                self.approved = fresh.approved
            }
            return response
        }
    }

    /// Withdraw a request, or stop teaching at a venue.
    func end(_ link: Components.Schemas.MyCoachLink, _ session: SessionModel) async {
        _ = await act(session) { client in
            let response = try await client.endMyCoachLink(path: .init(id: link.id))
            if case .ok = response { await self.load(session) }
            return response
        }
    }

    func saveTerms(
        _ link: Components.Schemas.MyCoachLink,
        _ terms: Components.Schemas.SaveTeachingTermsRequest,
        _ session: SessionModel
    ) async -> Bool {
        await act(session) { client in
            let response = try await client.saveMyTeachingTerms(path: .init(id: link.id), body: .json(terms))
            if case .ok = response { await self.load(session) }
            return response
        }
    }

    func saveHours(
        _ link: Components.Schemas.MyCoachLink,
        _ hours: [Components.Schemas.CoachTeachingHours],
        _ session: SessionModel
    ) async -> Bool {
        await act(session) { client in
            let response = try await client.saveMyTeachingHours(path: .init(id: link.id), body: .json(.init(hours: hours)))
            if case .ok = response { await self.load(session) }
            return response
        }
    }

    /// Runs one write; on a refusal, says why in the web's words. Answers
    /// whether it went.
    private func act(_ session: SessionModel, _ call: (Client) async throws -> Any) async -> Bool {
        guard let client = await session.client() else { return false }
        busy = true
        defer { busy = false }
        line = nil
        do {
            let response = try await call(client)
            guard let error = apiError(response) else { return true }
            line = (CoachVenueText.error(error), true)
            return false
        } catch {
            line = (String(localized: "coachVenues.error.NETWORK"), true)
            return false
        }
    }
}
