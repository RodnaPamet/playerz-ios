/// The sports this build knows, in the server's order (projectZ `SportType`).
///
/// The set is open (#34): the server adds sports, and a game, a venue or a
/// profile may carry one this build has never seen. The client decodes any
/// value as a `String`; this list is only what the app can offer to filter by
/// and name in its own words. A test keeps it equal to the spec's
/// `x-known-values`.
public enum Sports {
    public static let known: [String] = [
        "TENNIS", "PADEL", "BADMINTON", "TABLE_TENNIS", "BEACH_TENNIS", "PICKLEBALL",
        "SQUASH", "FOOTBALL5", "FOOTBALL", "BASKETBALL", "VOLLEYBALL", "BEACH_VOLLEYBALL",
        "HANDBALL", "CHESS", "ESPORTS", "KARTING", "RUNNING", "CYCLING",
    ]
}
