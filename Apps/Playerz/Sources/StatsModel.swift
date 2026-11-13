import Foundation
import Observation
import PlayerzAPI

/// What «Профил» shows (playerz-ios#95): the caller's statistics in one sport
/// (`GET /me/stats`), their counted matches (`GET /me/matches`), and the
/// starting-level questionnaire for that sport (`GET /skill-survey`).
@MainActor
@Observable
final class StatsModel {
    enum Phase { case loading, loaded, failed }

    typealias Stats = Components.Schemas.MyStats
    typealias Match = Components.Schemas.MyMatch
    typealias Survey = Components.Schemas.SkillSurvey

    private(set) var phase: Phase = .loading
    private(set) var stats: Stats?
    /// The sport asked for; nil until the player picks one, when the server
    /// shows the sport they play most.
    var sport: String?

    private(set) var matches: [Match] = []
    private(set) var matchesPhase: Phase = .loading
    private(set) var nextCursor: String?
    private var matchesSport: String?

    /// The questionnaire for the sport on show, nil where it has none.
    private(set) var survey: Survey?
    /// The sports that have one, as the server lists them.
    private(set) var surveySports: [String] = []

    /// The sport on show: the one picked, else the server's choice.
    var shownSport: String? { sport ?? stats?.sport }

    /// Every sport the pill offers: those played or declared, then those
    /// with a questionnaire, so a newcomer can start one.
    var offeredSports: [String] {
        let mine = stats?.sports ?? []
        return mine + surveySports.filter { !mine.contains($0) }
    }

    /// The questionnaire card: there is one, and no counted match has moved
    /// the level yet (the server refuses it after that).
    var offersSurvey: Bool {
        survey != nil && (stats?.rating?.matchesRated ?? 0) == 0
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            phase = stats == nil ? .failed : .loaded
            return
        }
        do {
            let fresh = try await client.getMyStats(query: .init(sport: sport)).ok.body.json.data
            stats = fresh
            phase = .loaded
            await loadSurvey(client, for: fresh.sport ?? sport)
        } catch {
            // A failed reload keeps what is shown.
            if stats == nil { phase = .failed }
        }
    }

    /// The first page of matches, again when the sport changed.
    func loadMatches(_ session: SessionModel) async {
        guard let client = await session.client() else {
            matchesPhase = .failed
            return
        }
        let wanted = shownSport
        do {
            let page = try await client.listMyMatches(query: .init(sport: wanted)).ok.body.json.data
            matches = page.items
            nextCursor = page.nextCursor
            matchesSport = wanted
            matchesPhase = .loaded
        } catch {
            if matches.isEmpty || matchesSport != wanted { matchesPhase = .failed }
        }
    }

    /// The next page, when the list's end comes on screen.
    func loadMoreMatches(_ session: SessionModel) async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        guard let page = try? await client.listMyMatches(query: .init(sport: matchesSport, cursor: cursor))
            .ok.body.json.data
        else {
            nextCursor = cursor
            return
        }
        matches += page.items
        nextCursor = page.nextCursor
    }

    /// The questionnaire for `sport`; with none chosen, padel's call still
    /// says which sports have one.
    private func loadSurvey(_ client: Client, for sport: String?) async {
        let asked = sport ?? "PADEL"
        guard let response = try? await client.getSkillSurvey(query: .init(sport: asked)) else { return }
        switch response {
        case let .ok(ok):
            let found = try? ok.body.json.data
            surveySports = found?.sports ?? surveySports
            survey = sport == nil ? nil : found
        case .notFound:
            survey = nil
        default:
            break
        }
    }

    /// The answers, scored by the server: the starting level, or nil when it
    /// refused them (a counted match since, or a failure).
    func submit(_ answers: [String: String], sport: String, _ session: SessionModel) async -> Int? {
        guard let client = await session.client(),
              let response = try? await client.submitSkillSurvey(
                body: .json(.init(sport: sport, answers: .init(additionalProperties: answers)))
              ),
              case let .ok(ok) = response,
              let result = try? ok.body.json.data
        else { return nil }
        return result.level
    }
}
