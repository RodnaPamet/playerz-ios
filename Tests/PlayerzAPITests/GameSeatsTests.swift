import Foundation
import Testing

@testable import PlayerzAPI

/// Who stands where on a game's drawn court (playerz-ios#56): the organiser
/// first, then the players, the places wanted and the places not offered,
/// the organiser's side filling first.
@Suite("Game seats")
struct GameSeatsTests {
    private typealias Seat = GameSeats.Seat

    private func all(_ seats: GameSeats) -> [Seat] { seats.left + seats.right }

    @Test("a doubles court: organiser, one player, two places wanted")
    func doubles() {
        let seats = GameSeats(capacity: 4, players: 2, spotsLeft: 2, viewerIsBooker: false, viewerIsPlaying: false)
        #expect(seats.left == [.organiser(isYou: false), .taken])
        #expect(seats.right == [.open, .open])
        #expect(seats.hidden == 0)
    }

    @Test("places the organiser did not offer are drawn as closed")
    func closedPlaces() {
        let seats = GameSeats(capacity: 4, players: 1, spotsLeft: 1, viewerIsBooker: true, viewerIsPlaying: true)
        #expect(all(seats) == [.organiser(isYou: true), .open, .closed, .closed])
    }

    @Test("an accepted player sees their own seat")
    func viewerSeat() {
        let seats = GameSeats(capacity: 4, players: 3, spotsLeft: 1, viewerIsBooker: false, viewerIsPlaying: true)
        #expect(all(seats) == [.organiser(isYou: false), .you, .taken, .open])
    }

    @Test("named players take their seats; any the server counts beyond them stay anonymous")
    func namedPlayers() {
        let maria = GameSeats.Person(name: "Мария", picture: nil, level: "4,5")
        let seats = GameSeats(
            capacity: 4, players: 3, spotsLeft: 1, viewerIsBooker: false, viewerIsPlaying: true,
            named: [.you, .player(maria)]
        )
        #expect(all(seats) == [.organiser(isYou: false), .you, .player(maria), .open])
        let fewer = GameSeats(
            capacity: 4, players: 3, spotsLeft: 0, viewerIsBooker: false, viewerIsPlaying: false,
            named: [.player(maria)]
        )
        #expect(all(fewer) == [.organiser(isYou: false), .player(maria), .taken, .closed])
    }

    @Test("a count the server got wrong loses neither a player nor a place")
    func badCounts() {
        let seats = GameSeats(capacity: 2, players: 2, spotsLeft: 2, viewerIsBooker: false, viewerIsPlaying: false)
        #expect(all(seats).count == 4)
        let none = GameSeats(capacity: 4, players: 0, spotsLeft: -1, viewerIsBooker: false, viewerIsPlaying: false)
        #expect(all(none).first == .organiser(isYou: false))
        #expect(!all(none).contains(.open))
    }

    @Test("a large game draws at most twelve seats and counts the rest")
    func largeGame() {
        let seats = GameSeats(capacity: 16, players: 6, spotsLeft: 4, viewerIsBooker: false, viewerIsPlaying: false)
        #expect(all(seats).count == GameSeats.most)
        #expect(seats.hidden == 4)
        #expect(seats.left.count == 6 && seats.right.count == 6)
    }

    @Test("an odd number of seats puts the extra one on the organiser's side")
    func oddSeats() {
        let seats = GameSeats(capacity: 3, players: 1, spotsLeft: 2, viewerIsBooker: false, viewerIsPlaying: false)
        #expect(seats.left.count == 2 && seats.right.count == 1)
    }
}
