import PlayerzAPI
import SwiftUI

/// A booking's result (playerz-ios#18), on the player's booking once it is
/// over, as the web's:
///
///     no result, may report   «Въведи резултат»: the sides and the score
///     reported, by my side    waiting for the other side, until when
///     reported, to me         «Потвърди» or «Оспори» (a note for the club)
///     answered or decided     the result and where it stands
///
/// Nothing at all for a booking that cannot have one: still ahead, a sport
/// with no score, or past its 7 days with nothing reported. The booking's
/// screen reads it (`standing`), only while the ranking module is on.
struct BookingResultSection: View {
    static let anchor = "result"

    let bookingId: String
    /// The venue's: deadlines on its clock, as the booking's own times.
    let timezone: String
    @Binding var standing: Components.Schemas.BookingResultState?
    @Bindable var session: SessionModel

    @State private var busy = false
    @State private var rejecting = false
    @State private var problem: String?

    var body: some View {
        if let standing, standing.result != nil || standing.canReport {
            Section(String(localized: "myBookings.result.heading")) {
                if let result = standing.result {
                    LabeledContent(String(localized: "myBookings.detail.status"), value: ResultText.status(result.status.rawValue))
                    ResultSummaryView(
                        sides: result.sides,
                        score: result.score,
                        winnerSide: result.winnerSide,
                        format: standing.format.rawValue
                    )
                    if let caption = caption(result) {
                        Text(caption).font(.footnote).foregroundStyle(.secondary)
                    }
                    if result.canAnswer {
                        Button(String(localized: "myBookings.result.confirm"), action: confirm)
                            .disabled(busy)
                        Button(String(localized: "myBookings.result.reject"), role: .destructive, action: reject)
                            .disabled(busy)
                            // On the button, not the Section: a Section's modifiers apply to each row.
                            .sheet(isPresented: $rejecting) {
                                RejectResultSheet(send: sendReject)
                            }
                    }
                } else {
                    Text(intro(standing)).font(.footnote).foregroundStyle(.secondary)
                    NavigationLink(String(localized: "myBookings.result.report")) {
                        ResultEditorView(bookingId: bookingId, standing: standing, session: session, sent: show)
                    }
                }
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
        }
    }

    private func caption(_ result: Components.Schemas.ResultView) -> String? {
        switch result.status {
        case .REPORTED:
            guard let until = result.autoConfirmAt else { return nil }
            let deadline = GameText.when(until, timezone: timezone)
            return result.canAnswer
                ? String(localized: "myBookings.result.answerUntil \(deadline)")
                : String(localized: "myBookings.result.waitingUntil \(deadline)")
        case .REJECTED:
            return String(localized: "myBookings.result.withClub")
        default:
            return nil
        }
    }

    private func intro(_ standing: Components.Schemas.BookingResultState) -> String {
        var lines = [
            standing.reportableUntil.map {
                String(localized: "myBookings.result.intro \(GameText.when($0, timezone: timezone))")
            } ?? String(localized: "myBookings.result.introNoDeadline"),
        ]
        if let total = standing.pointsTotal {
            lines.append(String(localized: "myBookings.result.pointsTotal \(total)"))
        }
        return lines.joined(separator: " ")
    }

    private func show(_ fresh: Components.Schemas.BookingResultState) {
        standing = fresh
    }

    private func load() async {
        guard let client = await session.client(),
              let fresh = try? await client.getBookingResult(path: .init(id: bookingId)).ok.body.json.data
        else { return }
        standing = fresh
    }

    private func confirm() {
        guard let id = standing?.result?.id else { return }
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.confirmResult(path: .init(id: id))
            if case .ok = response {
                await load()
            } else {
                problem = ResultText.error(response.flatMap { apiErrorCode($0) })
                await load()
            }
        }
    }

    private func reject() {
        rejecting = true
    }

    private func sendReject(_ note: String) {
        guard let id = standing?.result?.id else { return }
        rejecting = false
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try? await client.rejectResult(
                path: .init(id: id),
                body: .json(.init(note: trimmed.isEmpty ? nil : trimmed))
            )
            if case .ok = response {
                await load()
            } else {
                problem = ResultText.error(response.flatMap { apiErrorCode($0) })
                await load()
            }
        }
    }
}
