import PlayerzAPI
import SwiftUI

/// «Потвърдете урока» (#19): who, where, on which court, when, and what each
/// part costs, paid at the club; a note for the coach if they want.
///
/// One Idempotency-Key per sheet: a retry after a lost answer re-sends the
/// SAME key, so a lesson that did land is answered again, never booked twice.
/// The price the player saw goes as `expectedTotalCents`: if the court it was
/// for has gone and another costs more, the server refuses rather than charge
/// what was not shown.
struct LessonConfirmSheet: View {
    let coachSlug: String
    let coachName: String
    let venue: Components.Schemas.PublicCoachVenue
    let times: Components.Schemas.LessonTimes
    let time: Components.Schemas.LessonTime
    @Bindable var session: SessionModel
    let booked: (String) -> Void
    let refused: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var sending = false
    @State private var problem: String?
    @State private var key = UUID().uuidString

    private static let maxNotes = 500

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(String(localized: "coaches.lesson.sheet.coach"), value: coachName)
                    LabeledContent(String(localized: "coaches.lesson.sheet.venue"), value: venue.name)
                    LabeledContent(
                        String(localized: "coaches.lesson.sheet.court"),
                        value: String(localized: "coaches.lesson.sheet.courtOf \(time.court.name) \(GameText.sport(time.sport))")
                    )
                    LabeledContent(String(localized: "coaches.lesson.sheet.when")) {
                        Text(GameText.when(time.startTs, timezone: times.venue.timezone))
                    }
                }
                Section {
                    LabeledContent(String(localized: "coaches.lesson.sheet.coachFee"), value: CoachText.money(times.coachFeeCents, times.currency))
                    LabeledContent(String(localized: "coaches.lesson.sheet.courtPrice"), value: CoachText.money(time.courtPriceCents, times.currency))
                    LabeledContent(String(localized: "coaches.lesson.sheet.total")) {
                        Text(CoachText.money(time.totalCents, times.currency)).bold()
                    }
                } footer: {
                    Text(footer)
                }
                Section {
                    TextField(String(localized: "coaches.lesson.sheet.notes"), text: $notes, axis: .vertical)
                        .lineLimit(2...)
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
                Section {
                    Button(action: book) {
                        if sending { ProgressView() } else { Text(String(localized: "coaches.lesson.book")) }
                    }
                    .disabled(sending || notes.count > Self.maxNotes)
                }
            }
            .navigationTitle(String(localized: "coaches.lesson.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close"), action: close)
                }
            }
        }
    }

    /// Paid at the club; and when the club's cutoff has already passed for
    /// this start, that cancelling will be the club's.
    private var footer: String {
        let pay = String(localized: "coaches.lesson.sheet.payAtClub")
        let cutoff = time.startTs.addingTimeInterval(-Double(times.cancelCutoffHours) * 3600)
        guard times.cancelCutoffHours > 0, cutoff <= .now else { return pay }
        return "\(pay) \(String(localized: "coaches.lesson.sheet.noOnlineCancel \(times.cancelCutoffHours)"))"
    }

    private func close() {
        dismiss()
    }

    private func book() {
        sending = true
        problem = nil
        Task {
            defer { sending = false }
            guard let client = await session.client() else { return }
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let request = Components.Schemas.BookLessonRequest(
                linkId: times.linkId,
                startTs: time.startTs,
                minutes: times.minutes,
                sport: time.sport,
                notes: trimmed.isEmpty ? nil : trimmed,
                expectedTotalCents: time.totalCents
            )
            let response: Operations.bookLesson.Output
            do {
                response = try await client.bookLesson(
                    path: .init(slug: coachSlug),
                    headers: .init(Idempotency_hyphen_Key: key),
                    body: .json(request)
                )
            } catch {
                // The answer was lost, not refused: the same key may be sent again.
                problem = String(localized: "coaches.lesson.sheet.error.failed")
                return
            }
            switch response {
            case let .created(created):
                if let lesson = try? created.body.json.data { booked(lesson.value1.id) }
            case let .ok(ok):
                // The same key again: the lesson it booked the first time.
                if let lesson = try? ok.body.json.data { booked(lesson.value1.id) }
            default:
                let error = apiError(response)
                let text = CoachText.lessonError(
                    error?.code,
                    message: error?.message,
                    totalCents: apiErrorDetail(error, "totalCents"),
                    currency: times.currency
                )
                switch error?.code {
                case "PHONE_REQUIRED":
                    dismiss()
                    session.notice(refusal: "PHONE_REQUIRED")
                case "COACH_TAKEN", "SLOT_TAKEN", "LESSON_TIME_NOT_OFFERED", "SLOT_NOT_BOOKABLE", "LESSON_PRICE_CHANGED":
                    refused(text)
                default:
                    problem = text
                }
            }
        }
    }
}
