import PlayerzAPI
import SwiftUI

/// «Схема» (#22): the draw of any format, as the web draws it. The group
/// stage's tables and matches (one group for a round robin or a league), then
/// the knockout round by round, the final last, and the match for third.
struct TournamentDrawView: View {
    let id: String
    let timezone: String
    /// The tournament's venue: where a league match's time is proposed (#23).
    let venueId: String?
    @Bindable var session: SessionModel

    @State private var draw: Components.Schemas.Draw?
    @State private var failed = false
    @State private var proposing: ProposedMatch?
    @State private var busy = false
    @State private var problem: String?

    /// A league match whose time is being proposed, for `sheet(item:)`.
    struct ProposedMatch: Identifiable {
        let match: Components.Schemas.DrawMatch
        var id: String { match.id }
    }

    var body: some View {
        Group {
            if let draw {
                List {
                    if let problem {
                        Section { Text(problem).foregroundStyle(.red) }
                    }
                    ForEach(draw.groups, id: \.groupNo) { group in
                        Section(groupTitle(group.groupNo, of: draw.groups.count)) {
                            DrawTableView(table: group.table)
                            ForEach(group.matches, id: \.id) { match in
                                DrawMatchRow(match: match, timezone: timezone)
                                if leagueActions(match, in: draw) {
                                    LeagueMatchActions(
                                        match: match,
                                        timezone: timezone,
                                        busy: busy,
                                        propose: { proposing = ProposedMatch(match: match) },
                                        accept: { act(match) { client in try await client.acceptMatchTime(path: .init(id: match.id)) } },
                                        letGo: { act(match) { client in try await client.letGoMatchTime(path: .init(id: match.id)) } }
                                    )
                                }
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
        .sheet(item: $proposing) { proposed in
            if let venueId {
                ProposeMatchSheet(
                    venueId: venueId,
                    timezone: timezone,
                    opponents: opponents(proposed.match),
                    session: session
                ) { resourceId, startTs, minutes in
                    await propose(proposed.match, resourceId, startTs, minutes)
                }
            }
        }
    }

    /// Only a league's ready match the player plays, with no court yet, and
    /// only while the tournament runs, as the web.
    private func leagueActions(_ match: Components.Schemas.DrawMatch, in draw: Components.Schemas.Draw) -> Bool {
        draw.format == "LEAGUE" && draw.status == .IN_PROGRESS && match.mine && match.mySide != nil
            && match.status == .READY && match.scheduled == nil && (venueId != nil || match.proposal != nil)
    }

    /// The other side's players, for the sheet's sentence.
    private func opponents(_ match: Components.Schemas.DrawMatch) -> String {
        let theirs = match.mySide == 0 ? [match.sideB, match.sideB2] : [match.sideA, match.sideA2]
        return theirs.compactMap { $0 }.flatMap(\.players).map(TournamentText.person).joined(separator: " / ")
    }

    private func propose(_ match: Components.Schemas.DrawMatch, _ resourceId: String, _ startTs: Date, _ minutes: Int) async -> Bool {
        guard let client = await session.client() else { return false }
        problem = nil
        let response = try? await client.proposeMatchTime(
            path: .init(id: match.id),
            body: .json(.init(resourceId: resourceId, startTs: startTs, durationMinutes: minutes))
        )
        if case let .created(created)? = response, let fresh = try? created.body.json.data {
            draw = fresh
            return true
        }
        problem = TournamentText.error(response.flatMap { apiErrorCode($0) })
        await load()
        return false
    }

    /// Accept or let go of a proposed time; the draw as it now is either way.
    private func act(
        _ match: Components.Schemas.DrawMatch,
        _ call: @escaping (Client) async throws -> Any
    ) {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await call(client)
            if let response, apiError(response) != nil {
                problem = TournamentText.error(apiErrorCode(response))
            }
            await load()
        }
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
