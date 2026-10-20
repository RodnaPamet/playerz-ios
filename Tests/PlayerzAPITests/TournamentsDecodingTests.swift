import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for tournaments (playerz-ios#22), decoded through the
/// generated client.
///
/// Captured from the server's routes on the perf database, ranking on, after
/// the club's owner made three padel tournaments and opened them: a singles
/// knockout of four and a doubles round robin of two pairs, both filled,
/// confirmed and drawn; and one left open, entered (again: refused) and
/// withdrawn from. Entering the doubles without a partner is refused.
@Suite("Tournaments decode the server's JSON")
struct TournamentsDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(baseURL: URL(string: "https://playerz.test/api/v1")!, transport: Canned(replies: replies))
    }

    @Test func theOpenListAndATournament() async throws {
        let open = try await client(["listOpenTournaments": (200, OPEN)]).listOpenTournaments().ok.body.json.data.items
        #expect(open.count == 3)
        #expect(open.allSatisfy { $0.status == .REGISTRATION && $0.entriesOpen })
        let doubles = try #require(open.first { $0.teamSize == ._2 })
        #expect(doubles.format == .ROUND_ROBIN && doubles.feePayment == .AT_CLUB && doubles.entryFeeCents == 1000)
        let detail = try await client(["getTournament": (200, DETAIL)]).getTournament(path: .init(id: "t")).ok.body.json.data
        #expect(detail.value2.myEntry == nil)
        #expect(detail.value1.venue?.timezone == "Europe/Sofia")
        let club = try await client(["listClubPublicTournaments": (200, CLUB)])
            .listClubPublicTournaments(path: .init(slug: "c")).ok.body.json.data.items
        #expect(club.count == 3)
    }

    @Test func enteringAloneAndAsAPair() async throws {
        let entered = try await client(["enterTournament": (201, ENTERED)])
            .enterTournament(path: .init(id: "t"), body: .json(.init())).created.body.json.data
        let entry = try #require(entered.value2.myEntry)
        #expect(entry.status == .PENDING && entry.role == .entrant && entry.partner == nil)
        let pair = try await client(["enterTournament": (201, ENTERED_PAIR)])
            .enterTournament(path: .init(id: "t"), body: .json(.init(partnerUserId: "p"))).created.body.json.data
        #expect(pair.value2.myEntry?.partner?.name == "Елена Иванова")
        let mine = try await client(["listMyTournamentEntries": (200, MINE)]).listMyTournamentEntries().ok.body.json.data.items
        #expect(mine.count == 3)
        #expect(mine.allSatisfy { $0.value2.myEntry != nil })
    }

    @Test func refusals() async throws {
        let again = try await client(["enterTournament": (409, ALREADY)])
            .enterTournament(path: .init(id: "t"), body: .json(.init()))
        #expect(try again.conflict.body.json.error.code == "TOURNAMENT_ALREADY_ENTERED")
        let alone = try await client(["enterTournament": (400, PARTNER_REQUIRED)])
            .enterTournament(path: .init(id: "t"), body: .json(.init()))
        #expect(try alone.badRequest.body.json.error.code == "TOURNAMENT_PARTNER_REQUIRED")
        let gone = try await client(["withdrawTournamentEntry": (200, WITHDRAWN)])
            .withdrawTournamentEntry(path: .init(id: "e")).ok.body.json.data
        // Withdrawn: the tournament as a stranger sees it, so «Запиши се» shows again.
        #expect(gone.value2.myEntry == nil)
        #expect(gone.value1.entriesOpen)
    }

    @Test func aKnockoutDraw() async throws {
        let draw = try await client(["getTournamentDraw": (200, KNOCKOUT)])
            .getTournamentDraw(path: .init(id: "t")).ok.body.json.data
        #expect(draw.status == .IN_PROGRESS && draw.groups.isEmpty)
        #expect(draw.knockout.map(\.count) == [2, 1])
        let semi = try #require(draw.knockout.first?.first)
        #expect(semi.stage == .KNOCKOUT && semi.status == .READY)
        #expect(semi.sideA != nil && semi.sideB != nil)
        let final = try #require(draw.knockout.last?.first)
        #expect(final.status == .PENDING && final.sideA == nil)
        #expect(draw.knockout.flatMap { $0 }.contains { $0.mine })
    }

    @Test func aRoundRobinTable() async throws {
        let draw = try await client(["getTournamentDraw": (200, TABLE)])
            .getTournamentDraw(path: .init(id: "t")).ok.body.json.data
        let group = try #require(draw.groups.first)
        #expect(draw.groups.count == 1 && draw.knockout.isEmpty)
        #expect(group.table.map(\.rank) == [1, 2])
        #expect(group.table.allSatisfy { $0.played == 0 && $0.points == 0 })
        #expect(group.table.first?.entry.players.count == 2)
        #expect(group.matches.count == 1)
    }
}

private let OPEN = #"{"data":{"items":[{"id":"cmvh0epga003fkbizremo5wfi","name":"Есенна купа","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-10-25T18:21:13.000Z","endsAt":"2026-10-26T02:21:13.000Z","entriesCloseAt":"2026-10-24T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":0,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}},{"id":"cmvh0epid003gkbizyfv7849o","name":"Двойки в петък","sport":"PADEL","format":"ROUND_ROBIN","teamSize":2,"status":"REGISTRATION","startsAt":"2026-10-26T18:21:13.000Z","endsAt":"2026-10-27T02:21:13.000Z","entriesCloseAt":"2026-10-25T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":0,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}},{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":0,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}}]}}"#
private let DETAIL = #"{"data":{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":0,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":null}}"#
private let ENTERED = #"{"data":{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":1,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":{"id":"cmvh0eppf003jkbizz8jandgm","status":"PENDING","role":"entrant","partner":null,"waitingPosition":null,"createdAt":"2026-10-20T18:21:14.007Z","payment":null}}}"#
private let ALREADY = #"{"error":{"code":"TOURNAMENT_ALREADY_ENTERED","message":"You are already in this tournament.","requestId":"49215523-1b72-4271-a260-a7d3991aca4e"}}"#
private let PARTNER_REQUIRED = #"{"error":{"code":"TOURNAMENT_PARTNER_REQUIRED","message":"A doubles entry names a partner.","requestId":"0a01da3b-3479-4bdf-9e55-69931d861909"}}"#
private let ENTERED_PAIR = #"{"data":{"id":"cmvh0epid003gkbizyfv7849o","name":"Двойки в петък","sport":"PADEL","format":"ROUND_ROBIN","teamSize":2,"status":"REGISTRATION","startsAt":"2026-10-26T18:21:13.000Z","endsAt":"2026-10-27T02:21:13.000Z","entriesCloseAt":"2026-10-25T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":1,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":{"id":"cmvh0ewuv004ckbizx2zo80xd","status":"PENDING","role":"entrant","partner":{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false},"waitingPosition":null,"createdAt":"2026-10-20T18:21:23.268Z","payment":null}}}"#
private let CLUB = #"{"data":{"items":[{"id":"cmvh0epga003fkbizremo5wfi","name":"Есенна купа","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-10-25T18:21:13.000Z","endsAt":"2026-10-26T02:21:13.000Z","entriesCloseAt":"2026-10-24T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":4,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}},{"id":"cmvh0epid003gkbizyfv7849o","name":"Двойки в петък","sport":"PADEL","format":"ROUND_ROBIN","teamSize":2,"status":"REGISTRATION","startsAt":"2026-10-26T18:21:13.000Z","endsAt":"2026-10-27T02:21:13.000Z","entriesCloseAt":"2026-10-25T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":2,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}},{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":1,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"}}]}}"#
private let MINE = #"{"data":{"items":[{"id":"cmvh0epid003gkbizyfv7849o","name":"Двойки в петък","sport":"PADEL","format":"ROUND_ROBIN","teamSize":2,"status":"REGISTRATION","startsAt":"2026-10-26T18:21:13.000Z","endsAt":"2026-10-27T02:21:13.000Z","entriesCloseAt":"2026-10-25T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":2,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":{"id":"cmvh0ewuv004ckbizx2zo80xd","status":"PENDING","role":"entrant","partner":{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false},"waitingPosition":null,"createdAt":"2026-10-20T18:21:23.268Z","payment":null}},{"id":"cmvh0epga003fkbizremo5wfi","name":"Есенна купа","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-10-25T18:21:13.000Z","endsAt":"2026-10-26T02:21:13.000Z","entriesCloseAt":"2026-10-24T18:21:13.000Z","entriesOpen":true,"drawSize":4,"confirmed":0,"pending":4,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":{"id":"cmvh0ewmn003skbizufiowziw","status":"PENDING","role":"entrant","partner":null,"waitingPosition":null,"createdAt":"2026-10-20T18:21:22.981Z","payment":null}},{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":1,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":{"id":"cmvh0eppf003jkbizz8jandgm","status":"PENDING","role":"entrant","partner":null,"waitingPosition":null,"createdAt":"2026-10-20T18:21:14.007Z","payment":null}}]}}"#
private let KNOCKOUT = #"{"data":{"tournamentId":"cmvh0epga003fkbizremo5wfi","format":"SINGLE_ELIMINATION","status":"IN_PROGRESS","groups":[],"knockout":[[{"id":"cbyy8m0mf4kniptmbx0401h6g","stage":"KNOCKOUT","round":1,"slot":0,"groupNo":0,"sideA":{"id":"cmvh0ewmn003skbizufiowziw","seed":1,"withdrawn":false,"players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false}]},"sideB":{"id":"cmvh0ewsl0047kbizmk2ouyle","seed":4,"withdrawn":false,"players":[{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}]},"sideA2":null,"sideB2":null,"status":"READY","winnerSide":null,"score":null,"scheduled":null,"proposal":null,"mySide":0,"deadline":null,"overdue":false,"mine":true},{"id":"cnot0fg827n091210sujo8iry","stage":"KNOCKOUT","round":1,"slot":1,"groupNo":0,"sideA":{"id":"cmvh0ewom003xkbizmxfzci4q","seed":2,"withdrawn":false,"players":[{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}]},"sideB":{"id":"cmvh0ewqm0042kbiz5wygko2f","seed":3,"withdrawn":false,"players":[{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false}]},"sideA2":null,"sideB2":null,"status":"READY","winnerSide":null,"score":null,"scheduled":null,"proposal":null,"mySide":null,"deadline":null,"overdue":false,"mine":false}],[{"id":"cqysyt2mdhvcp3fc6czvvrbhs","stage":"KNOCKOUT","round":2,"slot":0,"groupNo":0,"sideA":null,"sideB":null,"sideA2":null,"sideB2":null,"status":"PENDING","winnerSide":null,"score":null,"scheduled":null,"proposal":null,"mySide":null,"deadline":null,"overdue":false,"mine":false}]],"thirdPlace":null}}"#
private let TABLE = #"{"data":{"tournamentId":"cmvh0epid003gkbizyfv7849o","format":"ROUND_ROBIN","status":"IN_PROGRESS","groups":[{"groupNo":1,"table":[{"entryId":"cmvh0ewuv004ckbizx2zo80xd","rank":1,"played":0,"won":0,"drawn":0,"lost":0,"points":0,"setsDiff":0,"gamesDiff":0,"entry":{"id":"cmvh0ewuv004ckbizx2zo80xd","seed":1,"withdrawn":false,"players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}]}},{"entryId":"cmvh0ewxc004jkbizwgap6ln0","rank":2,"played":0,"won":0,"drawn":0,"lost":0,"points":0,"setsDiff":0,"gamesDiff":0,"entry":{"id":"cmvh0ewxc004jkbizwgap6ln0","seed":2,"withdrawn":false,"players":[{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}]}}],"matches":[{"id":"c14s9ndp59ws7976axxctjlcu","stage":"GROUP","round":1,"slot":0,"groupNo":1,"sideA":{"id":"cmvh0ewuv004ckbizx2zo80xd","seed":1,"withdrawn":false,"players":[{"userId":"cmvgybdws003ihwiz4cuvzdwq","name":"Георги Петров","deleted":false},{"userId":"cmvgybdx4003khwizf8304u17","name":"Елена Иванова","deleted":false}]},"sideB":{"id":"cmvh0ewxc004jkbizwgap6ln0","seed":2,"withdrawn":false,"players":[{"userId":"cmvgybdx8003lhwizqq08vt69","name":"Димитър Петров","deleted":false},{"userId":"cmvgybdxb003mhwizoabo6b8z","name":"Десислава Петрова","deleted":false}]},"sideA2":null,"sideB2":null,"status":"READY","winnerSide":null,"score":null,"scheduled":null,"proposal":null,"mySide":0,"deadline":null,"overdue":false,"mine":true}]}],"knockout":[],"thirdPlace":null}}"#
private let WITHDRAWN = #"{"data":{"id":"cmvh0epjx003hkbizz92qska6","name":"Зимен турнир","sport":"PADEL","format":"SINGLE_ELIMINATION","teamSize":1,"status":"REGISTRATION","startsAt":"2026-11-01T18:21:13.000Z","endsAt":"2026-11-02T02:21:13.000Z","entriesCloseAt":"2026-10-31T18:21:13.000Z","entriesOpen":true,"drawSize":8,"confirmed":0,"pending":0,"entryFeeCents":1000,"feePayment":"AT_CLUB","description":"Турнир за аматьори, нива 2–5.","club":{"slug":"sofia-padel-club","name":"Sofia Padel Club"},"venue":{"id":"cmvgybdhm0003jwiz4mybdrct","name":"Sofia Padel Club","city":"Sofia","publicSlug":"sofia-padel-club","timezone":"Europe/Sofia"},"myEntry":null}}"#
