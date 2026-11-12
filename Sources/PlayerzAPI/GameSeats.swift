import Foundation

/// Who stands where on a game's drawn court. The server names only the
/// organiser; the other players are a count, so they are seats without a face.
public struct GameSeats: Equatable, Sendable {
    public enum Seat: Equatable, Sendable {
        /// The booker; `isYou` when the caller is the booker.
        case organiser(isYou: Bool)
        /// The caller, accepted into the game.
        case you
        /// A player the server counts but does not name.
        case taken
        /// A player the server names: only to the booker, a player, or whoever
        /// asked (owner 2026-11-12, projectZ#668).
        case player(Person)
        /// A place the organiser is looking to fill.
        case open
        /// A place on the court the organiser did not offer.
        case closed
    }

    /// More seats than this do not fit a phone's court at a tappable size.
    public static let most = 12

    public let left: [Seat]
    public let right: [Seat]
    /// Seats of a large game that are not drawn.
    public let hidden: Int

    public var isEmpty: Bool { left.isEmpty && right.isEmpty }

    /// Someone on the court: what a seat draws.
    public struct Person: Equatable, Sendable {
        public let name: String?
        public let picture: URL?
        /// «4,0», or nil when they hide it or have none.
        public let level: String?

        public init(name: String?, picture: URL?, level: String?) {
            self.name = name
            self.picture = picture
            self.level = level
        }
    }

    /// `picture` turns the server's address into one the app can load (a
    /// path is read from the server the app is signed in to).
    public init(game: Components.Schemas.OpenGame, picture: (String?) -> URL?) {
        let named = game.players.map { players in
            players.dropFirst().map { p in
                // The viewer's own seat says «Вие», as before players were named.
                if p.isYou { return Seat.you }
                return Seat.player(Person(
                    name: p.firstName,
                    picture: picture(p.avatarUrl),
                    level: p.level.map { $0.formatted(.number.precision(.fractionLength(1))) }
                ))
            }
        }
        self.init(
            capacity: game.capacity,
            players: game.playersCount,
            spotsLeft: game.spotsLeft,
            viewerIsBooker: game.viewer?.isBooker == true,
            viewerIsPlaying: game.viewer?.isPlaying == true,
            named: named
        )
    }

    /// `named`: everyone after the organiser, when the server names them.
    public init(
        capacity: Int, players: Int, spotsLeft: Int, viewerIsBooker: Bool, viewerIsPlaying: Bool,
        named: [Seat]? = nil
    ) {
        let players = max(players, 1)
        let spots = max(spotsLeft, 0)
        // A count the server got wrong must not lose a player or a free place.
        let total = max(capacity, players + spots)
        var seats: [Seat] = [.organiser(isYou: viewerIsBooker)]
        var others = players - 1
        if let named {
            // Named: each in their seat; any the server counts beyond them stay anonymous.
            seats += named.prefix(others)
            others -= min(named.count, others)
        } else if viewerIsPlaying, !viewerIsBooker, others > 0 {
            seats.append(.you)
            others -= 1
        }
        seats += Array(repeating: .taken, count: others)
        seats += Array(repeating: .open, count: spots)
        seats += Array(repeating: .closed, count: total - players - spots)
        hidden = max(seats.count - Self.most, 0)
        let shown = Array(seats.prefix(Self.most))
        // The organiser's side fills first, as two pairs form on a doubles court.
        let perSide = (shown.count + 1) / 2
        left = Array(shown.prefix(perSide))
        right = Array(shown.dropFirst(perSide))
    }
}
