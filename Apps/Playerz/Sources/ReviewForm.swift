import SwiftUI

/// Whole stars, and text if they want (#14, #19): the venue's review and the
/// coach's. Star-only reviews skip moderation; text is published once a
/// moderator has read it. `send` answers nil when it went, or what to say.
struct ReviewForm: View {
    let title: String
    let ratingLabel: String
    let maxLength: Int
    let send: (Int, String?) async -> String?
    let done: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0
    @State private var text = ""
    @State private var sending = false
    @State private var problem: String?

    var body: some View {
        Form {
            Section(ratingLabel) {
                Picker(ratingLabel, selection: $rating) {
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
                Text(String(localized: "myBookings.review.bodyHint \(maxLength)"))
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            Section {
                Button(String(localized: "myBookings.review.submit"), action: submit)
                    .disabled(rating == 0 || sending || text.count > maxLength)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        sending = true
        problem = nil
        Task {
            defer { sending = false }
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let refused = await send(rating, body.isEmpty ? nil : body) {
                problem = refused
            } else {
                done()
                dismiss()
            }
        }
    }
}
