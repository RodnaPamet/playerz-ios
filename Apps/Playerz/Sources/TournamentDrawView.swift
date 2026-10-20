import PlayerzAPI
import SwiftUI

/// «Схема» (#22): the draw of any format, as the web draws it. The group
/// stage's tables and matches (one group for a round robin or a league), then
/// the knockout round by round, the final last, and the match for third.
struct TournamentDrawView: View {
    let id: String
    let timezone: String
    @Bindable var session: SessionModel

    @State private var draw: Components.Schemas.Draw?
    @State private var failed = false

    var body: some View {
        Group {
            if let draw {
                List {
                    ForEach(draw.groups, id: \.groupNo) { group in
                        Section(groupTitle(group.groupNo, of: draw.groups.count)) {
                            DrawTableView(table: group.table)
                            ForEach(group.matches, id: \.id) { match in
                                DrawMatchRow(match: match, timezone: timezone)
                            }
                        }
                    }
                    ForEach(Array(draw.knockout.enumerated()), id: \.offset) { index, round in
                        Section(roundTitle(index, of: draw.knockout.count)) {
                            ForEach(round, id: \.id) { match in
                                DrawMatchRow(match: match, timezone: timezone)
                            }
                        }
                    }
                    if let third = draw.thirdPlace {
                        Section(String(localized: "tournaments.draw.thirdPlace")) {
                            DrawMatchRow(match: third, timezone: timezone)
                        }
                    }
                }
                .refreshable { await load() }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "tournaments.error.FAILED"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "tournaments.draw.heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// «Група А», or «Класиране» when there is only one.
    private func groupTitle(_ number: Int, of count: Int) -> String {
        guard count > 1 else { return String(localized: "tournaments.draw.table") }
        let letters = Array("АБВГДЕЖЗИКЛМНОПРСТУФХ")
        let letter = number >= 1 && number <= letters.count ? String(letters[number - 1]) : String(number)
        return String(localized: "tournaments.draw.group \(letter)")
    }

    /// The last rounds by name, as the web: final, semis, quarters; the rest by number.
    private func roundTitle(_ index: Int, of count: Int) -> String {
        switch count - 1 - index {
        case 0: String(localized: "tournaments.draw.final")
        case 1: String(localized: "tournaments.draw.semis")
        case 2: String(localized: "tournaments.draw.quarters")
        default: String(localized: "tournaments.draw.round \(index + 1)")
        }
    }

    private func retry() {
        failed = false
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            draw = try await client.getTournamentDraw(path: .init(id: id)).ok.body.json.data
            failed = false
        } catch {
            failed = draw == nil
        }
    }
}
