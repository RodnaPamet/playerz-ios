import PlayerzAPI
import SwiftUI

/// «Въведи резултат» (#18), as the web's editor: who played on which side,
/// then the score, side 1's number first in every row. The server checks a
/// set's winner and the side sizes; this only stops what is plainly not a
/// result (`ResultDraft`).
struct ResultEditorView: View {
    let bookingId: String
    let standing: Components.Schemas.BookingResultState
    @Bindable var session: SessionModel
    let sent: (Components.Schemas.BookingResultState) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ResultDraft
    @State private var sending = false
    @State private var problem: String?

    init(
        bookingId: String,
        standing: Components.Schemas.BookingResultState,
        session: SessionModel,
        sent: @escaping (Components.Schemas.BookingResultState) -> Void
    ) {
        self.bookingId = bookingId
        self.standing = standing
        self.session = session
        self.sent = sent
        _draft = State(initialValue: ResultDraft(
            players: standing.players.map(\.userId),
            format: standing.format == .PERIODS ? .periods : .total,
            fixedSides: standing.fixedSides?.map { $0.map(\.userId) }
        ))
    }

    var body: some View {
        Form {
            Group {
                Section(String(localized: "results.editor.sides")) {
                    if let fixed = standing.fixedSides {
                        ForEach(fixed.indices, id: \.self) { side in
                            LabeledContent(
                                String(localized: "results.editor.side \(side + 1)"),
                                value: ResultText.side(fixed[side])
                            )
                        }
                    } else {
                        ForEach(standing.players, id: \.userId) { player in
                            ResultSeatPicker(name: ResultText.name(player), seat: $draft[seat: player.userId])
                        }
                    }
                }
                Section {
                    ForEach(draft.rows.indices, id: \.self) { row in
                        ResultScoreRow(
                            label: draft.format == .periods
                                ? String(localized: "results.editor.set \(row + 1)")
                                : String(localized: "results.editor.total"),
                            first: $draft.rows[row][0],
                            second: $draft.rows[row][1]
                        )
                    }
                    if draft.canAddSet {
                        Button(String(localized: "results.editor.addSet"), systemImage: "plus", action: addSet)
                    }
                    if draft.canRemoveSet {
                        Button(role: .destructive, action: removeSet) {
                            Label(String(localized: "results.editor.removeSet"), systemImage: "minus")
                                .foregroundStyle(Theme.Palette.danger)
                        }
                    }
                } header: {
                    Text(draft.format == .periods
                        ? String(localized: "results.editor.scoreSets")
                        : String(localized: "results.editor.scoreTotal"))
                } footer: {
                    if let total = standing.pointsTotal {
                        Text(String(localized: "myBookings.result.pointsTotal \(total)"))
                    }
                }
                if let problem {
                    Section {
                        // The words say what is wrong; the colour and the sign only back them up.
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Palette.danger)
                    }
                }
            }
            .brandListRow()
            Section {
                Button(String(localized: "myBookings.result.send"), action: send)
                    .buttonStyle(.brandPrimary)
                    .disabled(sending)
            }
            .listPillRow()
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(String(localized: "myBookings.result.report"))
        .brandHeader(.back(String(localized: "myBookings.result.report")))
    }

    private func addSet() {
        draft.addSet()
    }

    private func removeSet() {
        draft.removeSet()
    }

    private func send() {
        let request: (sides: [[String]], score: [[Int]])
        do {
            request = try draft.request()
        } catch .sides {
            problem = String(localized: "results.editor.problemSides")
            return
        } catch {
            problem = String(localized: "results.editor.problemScore")
            return
        }
        problem = nil
        sending = true
        Task {
            defer { sending = false }
            guard let client = await session.client() else { return }
            let response = try? await client.reportBookingResult(
                path: .init(id: bookingId),
                body: .json(.init(sides: request.sides, score: request.score))
            )
            if case let .created(created) = response, let fresh = try? created.body.json.data {
                sent(fresh)
                dismiss()
            } else {
                problem = ResultText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
