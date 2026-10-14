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
    enum Tab: String { case play, games, messages, profile }

    #if DEBUG
    private static let env = ProcessInfo.processInfo.environment
    static var credentials: (email: String, password: String)? {
        guard let email = env["PLAYERZ_EMAIL"], let password = env["PLAYERZ_PASSWORD"] else { return nil }
        return (email, password)
    }
    static var tab: Tab? { env["PLAYERZ_TAB"].flatMap(Tab.init(rawValue:)) }
    static var conversation: String? { env["PLAYERZ_CONVERSATION"] }
    static var gamesMine: Bool { env["PLAYERZ_GAMES"] == "mine" }
    #else
    static let credentials: (email: String, password: String)? = nil
    static let tab: Tab? = nil
    static let conversation: String? = nil
    static let gamesMine = false
    #endif
}
