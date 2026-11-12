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
            Group {
                Section(ratingLabel) {
                    StarPicker(label: ratingLabel, rating: $rating)
                }
                Section {
                    TextField(String(localized: "myBookings.review.bodyLabel"), text: $text, axis: .vertical)
                        .lineLimit(4...)
                } footer: {
                    Text(String(localized: "myBookings.review.bodyHint \(maxLength)"))
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(Theme.Palette.danger) }
                }
            }
            .brandListRow()
            // The form's one action: the accent pill, on the page.
            Section {
                Button(String(localized: "myBookings.review.submit"), action: submit)
                    .buttonStyle(.brandPrimary)
                    .disabled(rating == 0 || sending || text.count > maxLength)
            }
            .listPillRow()
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(title)
        .brandHeader(.back(title))
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

/// One to five whole stars, as a row of stars to tap. VoiceOver reads it as
/// one adjustable control («3 звезди»), swiped up or down, as the inline
/// picker it replaces was a list of «1 звезда» … «5 звезди».
private struct StarPicker: View {
    let label: String
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1...5, id: \.self) { stars in
                Button {
                    rating = stars
                } label: {
                    Image(systemName: stars <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(stars <= rating ? Theme.Palette.accentText : Color.secondary)
                        .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Five stars must fit a row's width; past this size the value is read out anyway.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(rating == 0 ? "" : String(localized: "myBookings.review.stars \(rating)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(5, rating + 1)
            case .decrement: rating = max(1, rating - 1)
            @unknown default: break
            }
        }
    }
}
