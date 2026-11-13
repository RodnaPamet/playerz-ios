import Foundation

/// What a sport's place is called (owner 2026-11-13): «корт» for racket
/// sports, «игрище» for team ball sports, «маса» for table tennis and chess,
/// «зала» for esports, «писта» for karting, «трасе» for running and cycling;
/// «място» when it is several of them, or a sport this build does not know.
public enum PlaceWord: String, CaseIterable, Sendable {
    case court, pitch, table, hall, track, route, spot

    /// The word for `sport`.
    public static func of(_ sport: String) -> PlaceWord {
        switch sport {
        case "TENNIS", "PADEL", "BADMINTON", "SQUASH", "PICKLEBALL", "BEACH_TENNIS": .court
        case "FOOTBALL", "FOOTBALL5", "BASKETBALL", "VOLLEYBALL", "BEACH_VOLLEYBALL", "HANDBALL": .pitch
        case "TABLE_TENNIS", "CHESS": .table
        case "ESPORTS": .hall
        case "KARTING": .track
        case "RUNNING", "CYCLING": .route
        default: .spot
        }
    }

    /// One word for several sports: theirs when they agree, else «място».
    public static func common(_ sports: some Sequence<String>) -> PlaceWord {
        let words = Set(sports.map(of))
        return words.count == 1 ? words.first! : .spot
    }

    /// Bulgarian grammatical gender, for the adjectives that agree with the
    /// word («закрит корт», «закрито игрище», «закрита маса»).
    public enum Gender: String, Sendable { case masculine, neuter, feminine }

    public var gender: Gender {
        switch self {
        case .court: .masculine
        case .pitch, .route, .spot: .neuter
        case .table, .hall, .track: .feminine
        }
    }
}
