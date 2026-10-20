import PlayerzAPI
import SwiftUI

/// A coach's reviews (#19), newest first, ten at a time: the rating, each
/// review, and on the player's own «Изтрий»; on anyone else's «Подай сигнал».
struct CoachReviewsSection: View {
    let model: CoachReviewsModel
    @Bindable var session: SessionModel

    var body: some View {
        Section {
            if model.page != nil, model.items.isEmpty {
                Text(String(localized: "coaches.reviews.none")).foregroundStyle(.secondary)
            }
            ForEach(model.items, id: \.id) { review in
                CoachReviewRow(review: review)
                    .swipeActions {
                        if review.mine {
                            Button(String(localized: "coaches.reviews.delete"), role: .destructive) { model.askToDelete(review) }
                        } else {
                            Button(String(localized: "coaches.reviews.report")) { model.report(review) }
                        }
                    }
                    .accessibilityActions {
                        if review.mine {
                            Button(String(localized: "coaches.reviews.delete")) { model.askToDelete(review) }
                        } else {
                            Button(String(localized: "coaches.reviews.report")) { model.report(review) }
                        }
                    }
            }
            if model.page?.nextCursor != nil {
                Button(String(localized: "coaches.reviews.more"), action: more)
            }
            if let problem = model.problem {
                Text(problem).foregroundStyle(.red)
            }
        } header: {
            Text(header)
        }
    }

    private var header: String {
        guard let rating = model.page?.rating, rating.reviewCount > 0 else { return String(localized: "coaches.reviews.title") }
        let shown = rating.avgRating.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "coaches.reviews.summary \(shown) \(rating.reviewCount)")
    }

    private func more() {
        Task { await model.more(session) }
    }
}
