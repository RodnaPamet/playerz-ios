import Foundation

/// Where a DEBUG launch opens, from environment variables, so a screen can be
/// looked at on the simulator without driving taps:
///
///     SIMCTL_CHILD_PLAYERZ_SERVER_URL=http://localhost:3100/api/v1 \
///     SIMCTL_CHILD_PLAYERZ_EMAIL=… SIMCTL_CHILD_PLAYERZ_PASSWORD=… \
///     SIMCTL_CHILD_PLAYERZ_TAB=messages SIMCTL_CHILD_PLAYERZ_CONVERSATION=<id> \
///     xcrun simctl launch booted bg.playerz.app
///
/// Compiled out of release builds: nothing here can sign anyone in, or move
/// anyone, in a shipped app.
enum DebugLaunch {
    enum Tab: String { case play, games, bookings, messages, profile }
    /// Профил's deletion section (#9): `delete` scrolls to it, `confirm` also
    /// opens the confirmation. Nothing here deletes: the word is still typed.
    enum Profile: String { case delete, confirm }

    #if DEBUG
    private static let env = ProcessInfo.processInfo.environment
    static var credentials: (email: String, password: String)? {
        guard let email = env["PLAYERZ_EMAIL"], let password = env["PLAYERZ_PASSWORD"] else { return nil }
        return (email, password)
    }
    static var tab: Tab? { env["PLAYERZ_TAB"].flatMap(Tab.init(rawValue:)) }
    static var conversation: String? { env["PLAYERZ_CONVERSATION"] }
    static var gamesMine: Bool { env["PLAYERZ_GAMES"] == "mine" }
    static var bookingGame: String? { env["PLAYERZ_BOOKING_GAME"] }
    /// Играй opened on a club's page (`PLAYERZ_CLUB=<slug>`) or a venue (`PLAYERZ_VENUE=<id>`), #17.
    static var club: String? { env["PLAYERZ_CLUB"] }
    static var venue: String? { env["PLAYERZ_VENUE"] }
    static var booking: String? { env["PLAYERZ_BOOKING"] }
    static var bookingPlayers: String? { env["PLAYERZ_BOOKING_PLAYERS"] }
    static var invite: String? { env["PLAYERZ_INVITE"] }
    /// The bell's list open (#15), or a push's link as if tapped.
    static var notifications: Bool { env["PLAYERZ_NOTIFICATIONS"] == "1" }
    static var link: String? { env["PLAYERZ_LINK"] }
    static var profile: Profile? { env["PLAYERZ_PROFILE"].flatMap(Profile.init(rawValue:)) }
    #else
    static let credentials: (email: String, password: String)? = nil
    static let tab: Tab? = nil
    static let conversation: String? = nil
    static let gamesMine = false
    static let bookingGame: String? = nil
    static let club: String? = nil
    static let venue: String? = nil
    static let booking: String? = nil
    static let bookingPlayers: String? = nil
    static let invite: String? = nil
    static let notifications = false
    static let link: String? = nil
    static let profile: Profile? = nil
    #endif
}
