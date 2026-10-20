import PlayerzAPI
import SwiftUI

/// «Оцени обекта»: whole stars, and text if they want; star-only reviews skip
/// moderation, text is published once a moderator has read it.
struct VenueReviewForm: View {
    let clubSlug: String
    let bookingId: String
    @Bindable var session: SessionModel
    let done: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0
    @State private var text = ""
    @State private var sending = false
    @State private var problem: String?

    private static let maxLength = 2000

    var body: some View {
        Form {
            Section(String(localized: "myBookings.review.ratingLabel")) {
                Picker(String(localized: "myBookings.review.ratingLabel"), selection: $rating) {
                    ForEach(1...5, id: \.self) { stars in
                        Text(String(localized: "myBookings.review.stars \(stars)")).tag(stars)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                TextField(String(localized: "myBookings.review.bodyLabel"), text: $text, axis: .vertical)
                    .lineLimit(4...)
            } footer: {
                Text(String(localized: "myBookings.review.bodyHint \(Self.maxLength)"))
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            Section {
                Button(String(localized: "myBookings.review.submit"), action: send)
                    .disabled(rating == 0 || sending || text.count > Self.maxLength)
            }
        }
        .navigationTitle(String(localized: "myBookings.review.rate"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        sending = true
        problem = nil
        Task {
            defer { sending = false }
            guard let client = await session.client() else { return }
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try? await client.reviewBooking(
                path: .init(slug: clubSlug, id: bookingId),
                body: .json(.init(rating: rating, body: body.isEmpty ? nil : body))
            )
            if case .created = response {
                done()
                dismiss()
            } else {
                problem = BookingPlayerText.reviewError(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
