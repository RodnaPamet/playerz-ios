import Foundation
import PlayerzAPI
import Testing

@Suite("Booking invite links")
struct BookingInviteLinkTests {
    @Test("the token is read from a link the server made")
    func readsToken() throws {
        let url = try #require(URL(string: "https://playerz.bg/invite/booking/AbC-123_xyz"))
        #expect(BookingInviteLink.token(in: url) == "AbC-123_xyz")
    }

    @Test(
        "anything else is not an invite",
        arguments: [
            "https://playerz.bg/invite/booking/",
            "https://playerz.bg/invite/booking/a/b",
            "https://playerz.bg/invite/game/abc",
            "https://playerz.bg/venues/abc",
            "playerz://invite/booking/abc",
        ]
    )
    func rejects(_ link: String) throws {
        let url = try #require(URL(string: link))
        #expect(BookingInviteLink.token(in: url) == nil)
    }

    @Test("a token longer than the server takes is refused")
    func rejectsLongToken() throws {
        let url = try #require(URL(string: "https://playerz.bg/invite/booking/" + String(repeating: "a", count: 201)))
        #expect(BookingInviteLink.token(in: url) == nil)
    }
}
