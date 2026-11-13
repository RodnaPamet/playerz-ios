import Foundation

/// A sport's symbol. Its surface is drawn by SportPitch.
enum GameSport {
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
