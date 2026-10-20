import Foundation
import Observation
import PlayerzAPI

/// A coach's reviews (#19), for `CoachReviewsSection`. Owned by the coach's
/// page, which presents the delete dialog and the report sheet: on a List's
/// Section those would apply to every row.
@MainActor
@Observable
final class CoachReviewsModel {
    let slug: String
    private(set) var page: Components.Schemas.CoachReviewPage?
    private(set) var items: [Components.Schemas.CoachReview] = []
    var problem: String?
    var deleting: Components.Schemas.CoachReview?
    var confirmingDelete = false
    var reporting: Reported?

    /// A review being reported, for `sheet(item:)`.
    struct Reported: Identifiable {
        let id: String
    }

    init(slug: String) {
        self.slug = slug
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client(),
              let fresh = try? await client.listCoachReviews(path: .init(slug: slug)).ok.body.json.data
        else { return }
        page = fresh
        items = fresh.items
    }

    func more(_ session: SessionModel) async {
        guard let cursor = page?.nextCursor, let client = await session.client() else { return }
        if let next = try? await client
            .listCoachReviews(path: .init(slug: slug), query: .init(cursor: cursor))
            .ok.body.json.data {
            page = next
            items += next.items
            problem = nil
        } else {
            problem = String(localized: "coaches.reviews.moreError")
        }
    }

    func askToDelete(_ review: Components.Schemas.CoachReview) {
        deleting = review
        confirmingDelete = true
    }

    func delete(_ review: Components.Schemas.CoachReview, _ session: SessionModel) async {
        guard let client = await session.client() else { return }
        if case .noContent = try? await client.deleteMyCoachReview(path: .init(id: review.id)) {
            problem = nil
            await load(session)
        } else {
            problem = String(localized: "coaches.reviews.deleteFailed")
        }
    }

    func report(_ review: Components.Schemas.CoachReview) {
        reporting = Reported(id: review.id)
    }

    func send(
        report id: String,
        reason: Components.Schemas.ReportRequest.reasonPayload,
        details: String,
        _ session: SessionModel
    ) async -> Bool {
        guard let client = await session.client() else { return false }
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try? await client.reportCoachReview(
            path: .init(id: id),
            body: .json(.init(reason: reason, details: trimmed.isEmpty ? nil : trimmed))
        )
        if case .created = response { return true }
        return false
    }
}
