/// A result being entered (playerz-ios#18), as the web's `ResultEditor`: who
/// played on which side, then the score, side 1's number first in every row.
///
///     PERIODS  a row a set: one to five, two to start with
///     TOTAL    one row: goals, points, or the game
///
/// Every player starts on a side, the first half on side 1, so a singles or a
/// doubles booking needs no change when it was booked in the order it was
/// played; «Не игра» leaves someone out. The server checks the rest (a set
/// with a winner, side sizes): this only stops what is plainly not a result.
public struct ResultDraft: Equatable, Sendable {
    public enum Seat: Hashable, Sendable {
        case side(Int)
        case out
    }

    public enum Format: Sendable {
        case periods
        case total
    }

    public enum Problem: Error, Equatable {
        /// A side with nobody on it.
        case sides
        /// A box that is not a number.
        case score
    }

    public static let maxSets = 5

    /// The booking's players, by user id, in the order the server lists them.
    public let players: [String]
    public let format: Format
    /// Set by a tournament's draw (#22): shown, not asked.
    public let fixedSides: Bool
    public var seats: [String: Seat]
    /// What was typed, side 1 first in each row.
    public var rows: [[String]]

    public init(players: [String], format: Format, fixedSides: [[String]]? = nil) {
        self.players = players
        self.format = format
        self.fixedSides = fixedSides != nil
        if let fixedSides {
            seats = Dictionary(uniqueKeysWithValues: players.map { id in
                let side = fixedSides.firstIndex { $0.contains(id) }
                return (id, side.map(Seat.side) ?? .out)
            })
        } else {
            let half = (players.count + 1) / 2
            seats = Dictionary(uniqueKeysWithValues: players.enumerated().map { index, id in
                (id, Seat.side(index < half ? 0 : 1))
            })
        }
        rows = format == .periods ? [["", ""], ["", ""]] : [["", ""]]
    }

    public var canAddSet: Bool { format == .periods && rows.count < Self.maxSets }
    public var canRemoveSet: Bool { format == .periods && rows.count > 1 }

    public mutating func addSet() {
        if canAddSet { rows.append(["", ""]) }
    }

    public mutating func removeSet() {
        if canRemoveSet { rows.removeLast() }
    }

    /// The sides and score to send, or what is plainly wrong.
    public func request() throws(Problem) -> (sides: [[String]], score: [[Int]]) {
        let sides = (0...1).map { side in players.filter { seats[$0] == .side(side) } }
        guard sides.allSatisfy({ !$0.isEmpty }) else { throw .sides }
        var score: [[Int]] = []
        for row in rows {
            let numbers = row.map { Self.number($0) }
            guard numbers.count == 2, let first = numbers[0], let second = numbers[1] else { throw .score }
            score.append([first, second])
        }
        return (sides, score)
    }

    /// One to three digits, as the web's form takes them.
    private static func number(_ typed: String) -> Int? {
        let digits = typed.trimmingCharacters(in: .whitespaces)
        guard (1...3).contains(digits.count), digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }
}
