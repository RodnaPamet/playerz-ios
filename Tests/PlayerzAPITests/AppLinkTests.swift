import Testing

@testable import PlayerzAPI

@Suite("Links to the app's screens")
struct AppLinkTests {
    @Test(
        "the paths the server writes",
        arguments: [
            ("/me/bookings/cmv1", AppLink.booking("cmv1")),
            ("/messages/c8tx", .conversation("c8tx")),
            ("/messages", .messages),
            ("/me/bookings", .bookings),
            ("/games?tab=mine", .games(mine: true)),
            ("/games", .games(mine: false)),
            ("https://playerz.bg/me/bookings/cmv1", .booking("cmv1")),
        ]
    )
    func routes(path: String, link: AppLink) {
        #expect(AppLink(path: path) == link)
    }

    @Test(
        "a path with no screen in the app opens nothing",
        arguments: ["/", "/tournaments/t1", "/t/club/admin/messages/c1", "/coach/profile", "/me/bookings/a/b", ""]
    )
    func noScreen(path: String) {
        #expect(AppLink(path: path) == nil)
    }

    @Test("without a link it can use, the reference decides")
    func refTypeFallback() {
        #expect(AppLink(href: nil, refType: "booking", refId: "b1") == .booking("b1"))
        #expect(AppLink(href: "/tournaments/t1", refType: "conversation", refId: "c1") == .conversation("c1"))
        #expect(AppLink(href: nil, refType: "tournament", refId: "t1") == nil)
        #expect(AppLink(href: "/me/bookings/b2", refType: "booking", refId: "b1") == .booking("b2"))
    }
}
