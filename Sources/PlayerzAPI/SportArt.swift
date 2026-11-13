/// Which banner photo stands for a sport (owner 2026-11-13: "use the pictures
/// to highlight each selected sport page"). The app bundles one picture per
/// known sport as `sport-<key>.webp`; a sport the server adds later has none
/// and the screen falls back to its drawn surface (SportPitch).
///
/// The pictures are illustrative category art, not a club's place: a club's
/// own photo always wins over them.
public enum SportArt {
    /// The file key for `sport`, or nil for a sport without a picture.
    public static func key(_ sport: String) -> String? {
        switch sport {
        case "TENNIS": "tennis"
        case "PADEL": "padel"
        case "BADMINTON": "badminton"
        case "TABLE_TENNIS": "table-tennis"
        case "BEACH_TENNIS": "beach-tennis"
        case "PICKLEBALL": "pickleball"
        case "SQUASH": "squash"
        case "FOOTBALL5": "football-5x5"
        case "FOOTBALL": "football"
        case "BASKETBALL": "basketball"
        case "VOLLEYBALL": "volleyball"
        case "BEACH_VOLLEYBALL": "beach-volleyball"
        case "HANDBALL": "handball"
        case "CHESS": "chess"
        case "ESPORTS": "esports"
        case "KARTING": "karting"
        case "RUNNING": "running"
        case "CYCLING": "cycling"
        default: nil
        }
    }

    /// The bundled file's name without its extension.
    public static func resource(_ sport: String) -> String? {
        key(sport).map { "sport-\($0)" }
    }
}
