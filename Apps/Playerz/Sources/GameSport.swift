import Foundation

/// How a sport is drawn: its symbol, and the lines of its court.
enum GameSport {
    enum Court {
        /// Two sides and a net: tennis, padel, volleyball.
        case net
        /// A halfway line and a centre circle: football, basketball, handball.
        case pitch
        /// Anything else: two sides, no markings that would be wrong.
        case plain
    }

    static func court(_ sport: String) -> Court {
        switch sport {
        case "TENNIS", "PADEL", "BADMINTON", "TABLE_TENNIS", "BEACH_TENNIS", "PICKLEBALL",
             "VOLLEYBALL", "BEACH_VOLLEYBALL":
            .net
        case "FOOTBALL", "FOOTBALL5", "BASKETBALL", "HANDBALL":
            .pitch
        default:
            .plain
        }
    }

    /// An SF Symbol for the sport; a sport added after this build gets the court.
    static func symbol(_ sport: String) -> String {
        switch sport {
        case "TENNIS": "tennisball"
        case "PADEL", "BEACH_TENNIS": "tennis.racket"
        case "BADMINTON": "figure.badminton"
        case "TABLE_TENNIS": "figure.table.tennis"
        case "PICKLEBALL": "figure.pickleball"
        case "SQUASH": "figure.squash"
        case "FOOTBALL", "FOOTBALL5": "soccerball"
        case "BASKETBALL": "basketball"
        case "VOLLEYBALL", "BEACH_VOLLEYBALL": "volleyball"
        case "HANDBALL": "figure.handball"
        case "CHESS": "checkerboard.rectangle"
        case "ESPORTS": "gamecontroller"
        case "KARTING": "flag.checkered"
        case "RUNNING": "figure.run"
        case "CYCLING": "figure.outdoor.cycle"
        default: "sportscourt"
        }
    }
}
