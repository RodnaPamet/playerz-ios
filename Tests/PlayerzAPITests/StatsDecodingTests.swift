import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for «Профил» (playerz-ios#95), decoded through the
/// generated client: `GET /me/stats` and `/me/matches` for the demo player on
/// the local server (synthetic seed data), and tennis's questionnaire.
@Suite("«Профил» decodes the server's JSON")
struct StatsDecodingTests {
    private static let replies: [String: (Int, String)] = [
        "getMyStats": (200, STATS),
        "listMyMatches": (200, MATCHES),
        "getSkillSurvey": (200, SURVEY),
        "submitSkillSurvey": (200, #"{"data":{"sport":"TENNIS","level":4}}"#),
    ]

    private func client(_ override: [String: (Int, String)] = [:]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: Self.replies.merging(override) { _, new in new })
        )
    }

    @Test func theStats() async throws {
        let stats = try await client().getMyStats().ok.body.json.data
        #expect(stats.sport == "PADEL")
        #expect(stats.sports == ["PADEL", "TENNIS"])
        let rating = try #require(stats.rating)
        #expect(rating.level == 4.2)
        #expect(rating.series.count == 5)
        #expect(rating.peak?.level == 4.9)
        #expect(stats.performance.games == 5)
        #expect(stats.performance.wins == 3)
        #expect(stats.performance.currentStreak?.outcome == .LOSS)
        #expect(stats.form.count == 5)
        #expect(stats.sets?.setsWon == 6)
        #expect(stats.partners.first?.person.name == "Мария Георгиева")
        #expect(stats.rivals.count == 3)
        #expect(stats.activity.months.count == 12)
        #expect(stats.activity.weekdays.count == 7)
        #expect(stats.activity.hours.count == 24)
        #expect(stats.activity.venues.first?.value1.name == "Падел клуб Лозенец")
        #expect(stats.activity.venues.first?.value2.games == 5)
        let standing = try #require(stats.standing)
        #expect(standing.rank == 3)
        #expect(standing.rows.contains { $0.isYou })
        #expect(stats.milestones.map(\.kind) == ["PEAK_LEVEL", "BEST_WIN_STREAK", "TOP_PARTNER", "FIRST_WIN"])
    }

    @Test func aNewcomer() async throws {
        // No sport, no rating, nothing played: everything empty or null.
        let empty = #"{"data":{"sports":[],"sport":null,"rating":null,"performance":{"games":0,"wins":0,"losses":0,"draws":0,"winRate":null,"currentStreak":null,"bestWinStreak":0},"form":[],"sets":null,"partners":[],"rivals":[],"activity":{"months":[{"month":"2026-01","games":0},{"month":"2026-02","games":0},{"month":"2026-03","games":0},{"month":"2026-04","games":0},{"month":"2026-05","games":0},{"month":"2026-06","games":0},{"month":"2026-07","games":0},{"month":"2026-08","games":0},{"month":"2026-09","games":0},{"month":"2026-10","games":0},{"month":"2026-11","games":0},{"month":"2026-12","games":0}],"weekdays":[0,0,0,0,0,0,0],"hours":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"venues":[]},"standing":null,"milestones":[]}}"#
        let stats = try await client(["getMyStats": (200, empty)]).getMyStats().ok.body.json.data
        #expect(stats.sport == nil)
        #expect(stats.rating == nil)
        #expect(stats.sets == nil)
        #expect(stats.standing == nil)
        #expect(stats.performance.winRate == nil)
    }

    @Test func anUnknownMilestoneStillDecodes() async throws {
        // Milestone kinds are an open set (x-open-enum): a newer server's kind
        // must not fail the page.
        let newer = STATS.replacingOccurrences(of: "\"FIRST_WIN\"", with: "\"HAT_TRICK\"")
        let stats = try await client(["getMyStats": (200, newer)]).getMyStats().ok.body.json.data
        #expect(stats.milestones.contains { $0.kind == "HAT_TRICK" })
    }

    @Test func theMatches() async throws {
        let page = try await client().listMyMatches(query: .init(limit: 2)).ok.body.json.data
        #expect(page.items.count == 2)
        let first = try #require(page.items.first)
        #expect(first.score?.first?.count == 2)
        #expect(first.venue?.cityNames.bg.isEmpty == false)
        #expect(!first.opponents.isEmpty)
        #expect(StatsFacts.change(from: first.levelBefore, to: first.levelAfter) != nil)
    }

    @Test func theQuestionnaire() async throws {
        let survey = try await client().getSkillSurvey(query: .init(sport: "TENNIS")).ok.body.json.data
        #expect(survey.sport == "TENNIS")
        #expect(survey.questions.count == 8)
        #expect(survey.questions.first?.options.first?.text.bg == "Започвам сега")
        let result = try await client().submitSkillSurvey(
            body: .json(.init(sport: "TENNIS", answers: .init(additionalProperties: ["experience": "to2y"])))
        ).ok.body.json.data
        #expect(result.level == 4)
    }
}

private let STATS = #"""
{"data": {"sports": ["PADEL", "TENNIS"], "sport": "PADEL", "rating": {"level": 4.2, "provisional": false, "declaredLevel": 4, "matchesRated": 5, "series": [{"at": "2026-11-12T16:52:11.703Z", "level": 4.4}, {"at": "2026-11-12T16:52:12.040Z", "level": 4.9}, {"at": "2026-11-12T16:52:12.335Z", "level": 4.5}, {"at": "2026-11-12T16:52:12.609Z", "level": 4.8}, {"at": "2026-11-12T16:52:12.877Z", "level": 4.2}], "peak": {"level": 4.9, "at": "2026-11-12T16:52:12.040Z"}, "change30d": 0.2}, "performance": {"games": 5, "wins": 3, "losses": 2, "draws": 0, "winRate": 0.6, "currentStreak": {"outcome": "LOSS", "length": 1}, "bestWinStreak": 2}, "form": [{"matchId": "cmwdsctrx003gm8izj9krjvtk", "outcome": "LOSS", "at": "2026-11-07T13:00:00.000Z"}, {"matchId": "cmwdsctkk002om8izgqzdisxx", "outcome": "WIN", "at": "2026-11-08T13:00:00.000Z"}, {"matchId": "cmwdsctcv001wm8iz8k76lipm", "outcome": "LOSS", "at": "2026-11-09T13:00:00.000Z"}, {"matchId": "cmwdsct4q0013m8izt3zjfv5t", "outcome": "WIN", "at": "2026-11-10T13:00:00.000Z"}, {"matchId": "cmwdscsux0008m8izn4cdyb8d", "outcome": "WIN", "at": "2026-11-11T13:00:00.000Z"}], "sets": {"scoredMatches": 5, "setsWon": 6, "setsLost": 5, "gamesWon": 53, "gamesLost": 54, "closeSetsWon": 1, "closeSetsLost": 0}, "partners": [{"person": {"userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null}, "games": 2, "wins": 2}, {"person": {"userId": "cmwdscskg00009siz6o9j8gba", "name": "Георги Димитров", "avatarUrl": null}, "games": 2, "wins": 1}, {"person": {"userId": "cmwdscskx00019sizhem650lg", "name": "Петър Николов", "avatarUrl": null}, "games": 1, "wins": 0}], "rivals": [{"person": {"userId": "cmwdscskx00019sizhem650lg", "name": "Петър Николов", "avatarUrl": null}, "games": 4, "wins": 3}, {"person": {"userId": "cmwdscskg00009siz6o9j8gba", "name": "Георги Димитров", "avatarUrl": null}, "games": 3, "wins": 2}, {"person": {"userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null}, "games": 3, "wins": 1}], "activity": {"months": [{"month": "2025-12", "games": 0}, {"month": "2026-01", "games": 0}, {"month": "2026-02", "games": 0}, {"month": "2026-03", "games": 0}, {"month": "2026-04", "games": 0}, {"month": "2026-05", "games": 0}, {"month": "2026-06", "games": 0}, {"month": "2026-07", "games": 0}, {"month": "2026-08", "games": 0}, {"month": "2026-09", "games": 0}, {"month": "2026-10", "games": 0}, {"month": "2026-11", "games": 5}], "weekdays": [1, 1, 1, 0, 0, 1, 1], "hours": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0], "venues": [{"id": "cmv8b4sae0001toizquxvkz96", "name": "Падел клуб Лозенец", "city": "София", "cityKey": "sofia", "cityNames": {"bg": "София", "en": "Sofia"}, "games": 5, "wins": 3}]}, "standing": {"club": {"slug": "iosdemo-club", "name": "Падел клуб Лозенец"}, "rank": 3, "absent": null, "total": 8, "rows": [{"rank": 1, "userId": "cmwdscsl800029sizu3ogvx7b", "name": "Елена Стоянова", "avatarUrl": null, "level": 6.6, "matchesPlayed": 5, "isYou": false}, {"rank": 2, "userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null, "level": 6.1, "matchesPlayed": 5, "isYou": false}, {"rank": 3, "userId": "cmv8b4scu000atoiz3reo5s93", "name": "Иван Петров", "avatarUrl": null, "level": 4.2, "matchesPlayed": 5, "isYou": true}, {"rank": 4, "userId": "cmwdscskg00009siz6o9j8gba", "name": "Георги Димитров", "avatarUrl": null, "level": 3.6, "matchesPlayed": 5, "isYou": false}, {"rank": 5, "userId": "cmwdscslr00049siza4u2gdre", "name": "Десислава Колева", "avatarUrl": null, "level": 3.3, "matchesPlayed": 5, "isYou": false}]}, "milestones": [{"kind": "PEAK_LEVEL", "value": 4.9, "at": "2026-11-12T16:52:12.040Z", "person": null}, {"kind": "BEST_WIN_STREAK", "value": 2, "at": "2026-11-10T13:00:00.000Z", "person": null}, {"kind": "TOP_PARTNER", "value": 2, "at": null, "person": {"userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null}}, {"kind": "FIRST_WIN", "value": 1, "at": "2026-11-11T13:00:00.000Z", "person": null}]}}
"""#

private let MATCHES = #"""
{"data": {"sport": "PADEL", "items": [{"matchId": "cmwdsctrx003gm8izj9krjvtk", "playedAt": "2026-11-07T13:00:00.000Z", "outcome": "LOSS", "venue": {"id": "cmv8b4sae0001toizquxvkz96", "name": "Падел клуб Лозенец", "city": "София", "cityKey": "sofia", "cityNames": {"bg": "София", "en": "Sofia"}}, "partners": [{"userId": "cmwdscskg00009siz6o9j8gba", "name": "Георги Димитров", "avatarUrl": null}], "opponents": [{"userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null}, {"userId": "cmwdscskx00019sizhem650lg", "name": "Петър Николов", "avatarUrl": null}], "score": [[2, 6], [3, 6]], "levelBefore": 4.8, "levelAfter": 4.2, "tournament": null}, {"matchId": "cmwdsctkk002om8izgqzdisxx", "playedAt": "2026-11-08T13:00:00.000Z", "outcome": "WIN", "venue": {"id": "cmv8b4sae0001toizquxvkz96", "name": "Падел клуб Лозенец", "city": "София", "cityKey": "sofia", "cityNames": {"bg": "София", "en": "Sofia"}}, "partners": [{"userId": "cmv8b4sds000ctoize9iesw48", "name": "Мария Георгиева", "avatarUrl": null}], "opponents": [{"userId": "cmwdscskg00009siz6o9j8gba", "name": "Георги Димитров", "avatarUrl": null}, {"userId": "cmwdscskx00019sizhem650lg", "name": "Петър Николов", "avatarUrl": null}], "score": [[7, 6], [6, 4]], "levelBefore": 4.5, "levelAfter": 4.8, "tournament": null}], "nextCursor": "cmwdsctkk002om8izgqzdisxx"}}
"""#

private let SURVEY = #"""
{"data": {"sports": ["TENNIS", "PADEL"], "sport": "TENNIS", "questions": [{"id": "experience", "text": {"bg": "Откога играете тенис?", "en": "How long have you played tennis?"}, "options": [{"id": "starting", "text": {"bg": "Започвам сега", "en": "Just starting"}}, {"id": "under6m", "text": {"bg": "До 6 месеца", "en": "Under 6 months"}}, {"id": "to2y", "text": {"bg": "От 6 месеца до 2 години", "en": "6 months to 2 years"}}, {"id": "to5y", "text": {"bg": "2–5 години", "en": "2–5 years"}}, {"id": "over5y", "text": {"bg": "Над 5 години", "en": "Over 5 years"}}]}, {"id": "frequency", "text": {"bg": "Колко често играете?", "en": "How often do you play?"}, "options": [{"id": "yearly", "text": {"bg": "Няколко пъти в годината", "en": "A few times a year"}}, {"id": "monthly", "text": {"bg": "1–2 пъти в месеца", "en": "1–2 times a month"}}, {"id": "weekly", "text": {"bg": "Всяка седмица", "en": "Every week"}}, {"id": "twiceWeekly", "text": {"bg": "2 или повече пъти седмично", "en": "Twice a week or more"}}, {"id": "coached", "text": {"bg": "Тренирам с треньор и играя мачове редовно", "en": "I train with a coach and play matches regularly"}}]}, {"id": "groundstrokes", "text": {"bg": "Форхенд и бекхенд", "en": "Forehand and backhand"}, "options": [{"id": "hit", "text": {"bg": "Удрям топката, но рядко я насочвам", "en": "I hit it, rarely where I want"}}, {"id": "forehand", "text": {"bg": "Сигурен форхенд, бекхендът е по-слаб", "en": "Reliable forehand, weaker backhand"}}, {"id": "both", "text": {"bg": "И двата са сигурни, с насока и дълбочина", "en": "Both reliable, with direction and depth"}}, {"id": "attack", "text": {"bg": "Атакувам и от двете страни, с ефект по избор", "en": "I attack off both sides, spin as I choose"}}]}, {"id": "serve", "text": {"bg": "Сервис", "en": "Serve"}, "options": [{"id": "learning", "text": {"bg": "Още уча сервиса", "en": "Still learning it"}}, {"id": "safe", "text": {"bg": "Сигурен първи сервис, без сила", "en": "A safe first serve, no pace"}}, {"id": "placed", "text": {"bg": "Насочвам първия, сигурен втори", "en": "A placed first serve, a reliable second"}}, {"id": "weapon", "text": {"bg": "Сила и ефект, печеля точки от сервиса", "en": "Pace and spin; I win points off my serve"}}]}, {"id": "rally", "text": {"bg": "Разменяне от основната линия", "en": "Rallying from the baseline"}, "options": [{"id": "short", "text": {"bg": "Няколко удара и грешка", "en": "A few shots, then an error"}}, {"id": "moderate", "text": {"bg": "6–10 удара при умерено темпо", "en": "6–10 shots at a moderate pace"}}, {"id": "long", "text": {"bg": "Дълги разменяния, сменям посоката", "en": "Long rallies; I change direction"}}, {"id": "control", "text": {"bg": "Контролирам темпото и строя точката", "en": "I control the pace and build the point"}}]}, {"id": "net", "text": {"bg": "Воле и мрежа", "en": "Volleys and net"}, "options": [{"id": "rarely", "text": {"bg": "Рядко съм на мрежата", "en": "Rarely at the net"}}, {"id": "easy", "text": {"bg": "Воле при лесни топки", "en": "Volleys on easy balls"}}, {"id": "approach", "text": {"bg": "Излизам на мрежата след подготвящ удар", "en": "I come in behind an approach"}}, {"id": "serveVolley", "text": {"bg": "Сервис-воле и полуволе", "en": "Serve-and-volley and half-volleys"}}]}, {"id": "tactics", "text": {"bg": "Тактика", "en": "Tactics"}, "options": [{"id": "over", "text": {"bg": "Връщам топката през мрежата", "en": "I get it back over"}}, {"id": "weakSide", "text": {"bg": "Играя на слабата страна на противника", "en": "I play to the opponent's weak side"}}, {"id": "build", "text": {"bg": "Строя точката, сменям ритъма", "en": "I build points and change the rhythm"}}, {"id": "plan", "text": {"bg": "Имам план и го сменям по време на мача", "en": "I have a plan and change it mid-match"}}]}, {"id": "tournaments", "text": {"bg": "Турнири", "en": "Tournaments"}, "options": [{"id": "never", "text": {"bg": "Не съм играл/а", "en": "Never"}}, {"id": "amateur", "text": {"bg": "Приятелски и любителски турнири", "en": "Friendly and amateur tournaments"}}, {"id": "club", "text": {"bg": "Клубни и местни турнири, любителски ранглисти", "en": "Club and local tournaments, amateur rankings"}}, {"id": "federation", "text": {"bg": "БФТ ранглиста, ITF или по-високо", "en": "Bulgarian Tennis Federation ranking, ITF or higher"}}]}]}}
"""#
