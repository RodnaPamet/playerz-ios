import PlayerzAPI
import SwiftUI

/// One review: the stars, who (a first name, or «Играч»), when, and the text.
struct CoachReviewRow: View {
    let review: Components.Schemas.CoachReview

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(repeating: "★", count: review.rating) + String(repeating: "☆", count: max(0, 5 - review.rating)))
                    .accessibilityLabel(String(localized: "coaches.reviews.stars \(review.rating)"))
                Spacer()
                Text(review.createdAt, format: .dateTime.day().month().year())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(author).font(.subheadline).foregroundStyle(.secondary)
            if let body = review.body, !body.isEmpty {
                Text(body)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var author: String {
        let name = review.author ?? String(localized: "coaches.reviews.anonymous")
        return review.mine ? "\(name) · \(String(localized: "coaches.reviews.yours"))" : name
    }
}
