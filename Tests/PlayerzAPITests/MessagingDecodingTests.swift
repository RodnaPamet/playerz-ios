import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import PlayerzAPI

/// Real v1 responses for messaging (#375) and the profile switches, decoded
/// through the generated client (#484).
///
/// Captured from the server's route handlers on a real database: a player
/// writes to one they have not played with (a request), the other accepts and
/// replies, the first finds them by name and reads their card, writes to a
/// club, and joins the second's game, whose chat opens. The three kinds of
/// counterpart arrive as a `oneOf` without a discriminator, decoded by trying
/// each shape in turn, so each one is pinned here.
@Suite("Messaging decodes the server's JSON")
struct MessagingDecodingTests {
    private func client(_ replies: [String: (Int, String)]) -> Client {
        Playerz.client(
            baseURL: URL(string: "https://playerz.test/api/v1")!,
            transport: Canned(replies: replies)
        )
    }

    @Test func aRequestFromAPlayerNotPlayedWith() async throws {
        let mine = try await client(["getMyConversation": (200, A_PENDING)])
            .getMyConversation(path: .init(id: "c")).ok.body.json.data
        #expect(mine.state == .pending)
        #expect(mine.messages.first?.mine == true)
        let theirs = try await client(["getMyConversation": (200, B_REQUEST)])
            .getMyConversation(path: .init(id: "c")).ok.body.json.data
        #expect(theirs.state == .request)
        guard case .case1(let player) = theirs.counterpart else {
            Issue.record("a player conversation's counterpart is a player")
            return
        }
        #expect(player.name == "Иван Петров")
        let requests = try await client(["listMyConversations": (200, LIST_REQUESTS)])
            .listMyConversations(.init(query: .init(tab: .requests))).ok.body.json.data
        #expect(requests.items.count == 1)
        #expect(requests.items.first?.unreadCount == 1)
    }

    @Test func acceptedRepliedAndCounted() async throws {
        let c = client([
            "acceptMyConversation": (200, ACCEPT),
            "sendMyMessage": (201, REPLY),
            "getMyUnreadConversations": (200, UNREAD),
            "getMyConversation": (200, A_ACTIVE),
            "listMyConversations": (200, LIST),
        ])
        _ = try await c.acceptMyConversation(path: .init(id: "c")).ok
        let sent = try await c.sendMyMessage(
            path: .init(id: "c"), headers: .init(Idempotency_hyphen_Key: "k"), body: .json(.init(body: "x"))
        ).created.body.json.data
        #expect(sent.replayed == false)
        let unread = try await c.getMyUnreadConversations().ok.body.json.data
        #expect(unread.conversations == 1)
        let active = try await c.getMyConversation(path: .init(id: "c")).ok.body.json.data
        #expect(active.state == .active)
        #expect(active.canSend)
        #expect(active.messages.count == 2)
        let list = try await c.listMyConversations(.init()).ok.body.json.data
        #expect(list.items.first?.lastMessage?.mine == false)
    }

    @Test func aClubAndAGameChat() async throws {
        let opened = try await client(["openConversation": (201, OPEN_CLUB)])
            .openConversation(body: .json(.case2(.init(club: "s")))).created.body.json.data
        #expect(opened.created)
        let clubChat = try await client(["getMyConversation": (200, CLUB)])
            .getMyConversation(path: .init(id: "c")).ok.body.json.data
        guard case .case2 = clubChat.counterpart else {
            Issue.record("a club conversation's counterpart is the club")
            return
        }
        let game = try await client(["getMyConversation": (200, GAME_CHAT)])
            .getMyConversation(path: .init(id: "c")).ok.body.json.data
        guard case .case3(let chat) = game.counterpart else {
            Issue.record("a game chat's counterpart is the game")
            return
        }
        #expect(game.kind == .game)
        #expect(chat.members >= 2)
        let list = try await client(["listMyConversations": (200, LIST_AFTER_GAME)])
            .listMyConversations(.init()).ok.body.json.data
        #expect(list.items.contains { $0.kind == .game })
    }

    @Test func searchAndTheCard() async throws {
        let c = client(["searchPlayers": (200, SEARCH), "getPlayerCard": (200, CARD)])
        let found = try await c.searchPlayers(query: .init(q: "Мар")).ok.body.json.data
        #expect(found.first?.name == "Мария Георгиева")
        let card = try await c.getPlayerCard(path: .init(id: "p")).ok.body.json.data
        #expect(card.sports.first?.level == 4)
    }

    @Test func theProfileSwitchesAndABookingsPlayers() async throws {
        let c = client([
            "getMe": (200, ME),
            "getMyNotificationSettings": (200, SETTINGS),
            "listBookingParticipants": (200, PARTICIPANTS),
        ])
        let me = try await c.getMe().ok.body.json.data
        #expect(me.searchable)
        let settings = try await c.getMyNotificationSettings().ok.body.json.data
        #expect(settings.email.messages && settings.email.openPlay)
        let players = try await c.listBookingParticipants(path: .init(id: "b")).ok.body.json.data
        #expect(players.players.contains { $0.isBooker && $0.participantId == nil })
        #expect(players.players.contains { $0.isYou })
    }

    @Test func aRefusalCarriesItsCode() async throws {
        let response = try await client(["openConversation": (400, REFUSED)])
            .openConversation(body: .json(.case1(.init(playerId: "me"))))
        #expect(try response.badRequest.body.json.error.code == "CANNOT_MESSAGE_SELF")
    }
}


// Captured 2026-10-14 from the server's v1 route handlers (see the suite's comment).
private let A_PENDING = #"{"data":{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"deleted":false},"state":"pending","blockedByMe":false,"canSend":false,"unreadCount":0,"olderCursor":null,"messages":[{"id":"cmv8axf1g000bwmizejeq8bee","mine":true,"fromClub":false,"sender":{"name":"Иван Петров","deleted":false,"clubName":null},"body":"Здравей! Ще играеш ли в събота?","deleted":false,"createdAt":"2026-10-14T16:05:47.236Z"}]}}"#
private let B_REQUEST = #"{"data":{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axesx0005wmizhys4c51n","name":"Иван Петров","avatarUrl":null,"deleted":false},"state":"request","blockedByMe":false,"canSend":true,"unreadCount":1,"olderCursor":null,"messages":[{"id":"cmv8axf1g000bwmizejeq8bee","mine":false,"fromClub":false,"sender":{"name":"Иван Петров","deleted":false,"clubName":null},"body":"Здравей! Ще играеш ли в събота?","deleted":false,"createdAt":"2026-10-14T16:05:47.236Z"}]}}"#
private let LIST_REQUESTS = #"{"data":{"items":[{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axesx0005wmizhys4c51n","name":"Иван Петров","avatarUrl":null,"deleted":false},"state":"request","lastMessageAt":"2026-10-14T16:05:47.236Z","lastMessage":{"preview":"Здравей! Ще играеш ли в събота?","mine":false,"deleted":false},"unreadCount":1}],"nextCursor":null}}"#
private let ACCEPT = #"{"data":{"acceptedAt":"2026-10-14T16:05:47.435Z"}}"#
private let REPLY = #"{"data":{"id":"cmv8axf7q000ewmizyv3hz1p5","createdAt":"2026-10-14T16:05:47.462Z","replayed":false}}"#
private let UNREAD = #"{"data":{"conversations":1,"requests":0}}"#
private let A_ACTIVE = #"{"data":{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"deleted":false},"state":"active","blockedByMe":false,"canSend":true,"unreadCount":1,"olderCursor":null,"messages":[{"id":"cmv8axf1g000bwmizejeq8bee","mine":true,"fromClub":false,"sender":{"name":"Иван Петров","deleted":false,"clubName":null},"body":"Здравей! Ще играеш ли в събота?","deleted":false,"createdAt":"2026-10-14T16:05:47.236Z"},{"id":"cmv8axf7q000ewmizyv3hz1p5","mine":false,"fromClub":false,"sender":{"name":"Мария Георгиева","deleted":false,"clubName":null},"body":"Да, от 10.","deleted":false,"createdAt":"2026-10-14T16:05:47.462Z"}]}}"#
private let LIST = #"{"data":{"items":[{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"deleted":false},"state":"active","lastMessageAt":"2026-10-14T16:05:47.462Z","lastMessage":{"preview":"Да, от 10.","mine":false,"deleted":false},"unreadCount":1}],"nextCursor":null}}"#
private let OPEN_CLUB = #"{"data":{"id":"crvhwsnb1ytgkq1cmxclun1u0","created":true}}"#
private let CLUB = #"{"data":{"id":"crvhwsnb1ytgkq1cmxclun1u0","kind":"club","counterpart":{"kind":"club","clubId":"cmv8axepv0000wmizdakfanum","slug":"test-venue-xzcpo1rc-xzcpo1rc","name":"Test Venue xzcpo1rc"},"state":"active","blockedByMe":false,"canSend":true,"unreadCount":0,"olderCursor":null,"messages":[]}}"#
private let GAME_CHAT = #"{"data":{"id":"cittv4zoyixrlerj9jmtttnl9","kind":"game","counterpart":{"kind":"game","gameId":"cmv8axfeg000iwmizdhaou03b","bookingId":"cmv8axfd0000hwmizmrnxyk84","venueName":"Venue w8j4w6og","sport":"PADEL","startTs":"2026-10-16T16:05:47.650Z","endTs":"2026-10-16T17:05:47.650Z","timezone":"Europe/Sofia","members":2},"state":"active","blockedByMe":false,"canSend":true,"unreadCount":0,"olderCursor":null,"messages":[]}}"#
private let LIST_AFTER_GAME = #"{"data":{"items":[{"id":"cittv4zoyixrlerj9jmtttnl9","kind":"game","counterpart":{"kind":"game","gameId":"cmv8axfeg000iwmizdhaou03b","bookingId":"cmv8axfd0000hwmizmrnxyk84","venueName":"Venue w8j4w6og","sport":"PADEL","startTs":"2026-10-16T16:05:47.650Z","endTs":"2026-10-16T17:05:47.650Z","timezone":"Europe/Sofia","members":2},"state":"active","lastMessageAt":"2026-10-14T16:05:48.058Z","lastMessage":null,"unreadCount":0},{"id":"cf7rfhw65jex4igw9w5jewr0c","kind":"player","counterpart":{"kind":"player","userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"deleted":false},"state":"active","lastMessageAt":"2026-10-14T16:05:47.462Z","lastMessage":{"preview":"Да, от 10.","mine":false,"deleted":false},"unreadCount":1}],"nextCursor":null}}"#
private let SEARCH = #"{"data":[{"userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"sports":[{"sport":"PADEL","level":4,"rating":null}]}]}"#
private let CARD = #"{"data":{"userId":"cmv8axexj0008wmiz5grr2eoz","name":"Мария Георгиева","avatarUrl":null,"sports":[{"sport":"PADEL","level":4,"rating":null}]}}"#
private let ME = #"{"data":{"id":"cmv8axesx0005wmizhys4c51n","name":"Иван Петров","email":"ma-5zeggmmi@playerz.test","avatarUrl":null,"locale":"bg","sports":[{"sport":"PADEL","level":4}],"searchable":true,"ratingPublic":true,"accountKind":"PLAYER","phone":{"required":false,"verified":false,"number":null},"landing":{"reason":"player","club":null}}}"#
private let SETTINGS = #"{"data":{"email":{"confirmation":true,"reminder":true,"clubChanges":true,"messages":true,"openPlay":true,"lessonsTaught":true},"push":{"confirmation":true,"reminder":true,"clubChanges":true,"messages":true,"openPlay":true,"lessonsTaught":true},"pushDevices":0}}"#
private let PARTICIPANTS = #"{"data":{"viewerRole":"PARTICIPANT","capacity":4,"spotsLeft":2,"playersOpen":true,"liveInviteLinks":null,"players":[{"participantId":null,"name":"Мария Георгиева","avatarUrl":null,"isBooker":true,"isYou":false,"registered":true,"deleted":false},{"participantId":"cmv8axfnx000owmizz1ploofn","name":"Иван Петров","avatarUrl":null,"isBooker":false,"isYou":true,"registered":true,"deleted":false}]}}"#
private let REFUSED = #"{"error":{"code":"CANNOT_MESSAGE_SELF","message":"You cannot message yourself.","requestId":"351b3365-9268-481d-93b6-d744d1178a4e"}}"#
