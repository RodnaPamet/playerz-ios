import Foundation

/// Where a DEBUG launch opens, from environment variables, so a screen can be
/// looked at on the simulator without driving taps (an id route also takes
/// `first` or `last`, of those listed):
///
///     SIMCTL_CHILD_PLAYERZ_SERVER_URL=http://localhost:3100/api/v1 \
///     SIMCTL_CHILD_PLAYERZ_EMAIL=… SIMCTL_CHILD_PLAYERZ_PASSWORD=… \
///     SIMCTL_CHILD_PLAYERZ_TAB=messages SIMCTL_CHILD_PLAYERZ_CONVERSATION=<id> \
///     xcrun simctl launch booted bg.playerz.app
///
/// Compiled out of release builds: nothing here can sign anyone in, or move
/// anyone, in a shipped app.
enum DebugLaunch {
    /// The shell's tabs by their first names: `play` is «Начало», `games` is
    /// «Открий». `messages` is no longer a tab: it opens the inbox over «Начало».
    enum Tab: String { case play, games, bookings, messages, profile }
    /// Профил's deletion section (#9): `delete` scrolls to it, `confirm` also
    /// opens the confirmation. Nothing here deletes: the word is still typed.
    /// `ratings` opens «Класиране».
    /// `settings` opens «Настройки», behind the gear (#95).
    enum Profile: String { case delete, confirm, coach, ratings, settings }

    #if DEBUG
    private static let env = ProcessInfo.processInfo.environment
    static var credentials: (email: String, password: String)? {
        guard let email = env["PLAYERZ_EMAIL"], let password = env["PLAYERZ_PASSWORD"] else { return nil }
        return (email, password)
    }
    static var tab: Tab? { env["PLAYERZ_TAB"].flatMap(Tab.init(rawValue:)) }
    static var conversation: String? { env["PLAYERZ_CONVERSATION"] }
    static var gamesMine: Bool { env["PLAYERZ_GAMES"] == "mine" }
    /// Игри on «Турнири» (`PLAYERZ_GAMES=tournaments`), a tournament
    /// (`PLAYERZ_TOURNAMENT=<id>`), and its draw (also `PLAYERZ_TOURNAMENT_DRAW=1`), #22.
    static var gamesTournaments: Bool { env["PLAYERZ_GAMES"] == "tournaments" }
    static var tournament: String? { env["PLAYERZ_TOURNAMENT"] }
    /// «Открий» on a listed game's screen (`PLAYERZ_GAME=<id>`), or with one of its
    /// sheets open (`PLAYERZ_GAMES_SHEET=sport|filters|ask`). Nothing is sent.
    static var game: String? { env["PLAYERZ_GAME"] }
    static var gamesSheet: String? { env["PLAYERZ_GAMES_SHEET"] }
    static var tournamentDraw: Bool { env["PLAYERZ_TOURNAMENT_DRAW"] == "1" }
    static var bookingGame: String? { env["PLAYERZ_BOOKING_GAME"] }
    /// Играй opened on a club's page (`PLAYERZ_CLUB=<slug>`) or a venue (`PLAYERZ_VENUE=<id>`), #17.
    static var club: String? { env["PLAYERZ_CLUB"] }
    /// With `PLAYERZ_CLUB`, the club's «Класиране» on top (`PLAYERZ_CLUB_LEADERBOARD=1`), #18.
    static var clubLeaderboard: Bool { env["PLAYERZ_CLUB_LEADERBOARD"] == "1" }
    static var venue: String? { env["PLAYERZ_VENUE"] }
    static var booking: String? { env["PLAYERZ_BOOKING"] }
    static var bookingPlayers: String? { env["PLAYERZ_BOOKING_PLAYERS"] }
    static var invite: String? { env["PLAYERZ_INVITE"] }
    /// «Профил на треньор» opened on one of its screens (#21): `venues`, `terms`, `timeoff`, `lessons`.
    static var coachArea: String? { env["PLAYERZ_COACH_AREA"] }
    /// The bell's list open (#15), or a push's link as if tapped.
    static var notifications: Bool { env["PLAYERZ_NOTIFICATIONS"] == "1" }
    static var link: String? { env["PLAYERZ_LINK"] }
    /// A booking's result (#18): `section` scrolls to it, `editor` opens «Въведи резултат».
    static var result: String? { env["PLAYERZ_RESULT"] }
    /// Играй opened on «Треньори» (`PLAYERZ_COACHES=1`), a coach (`PLAYERZ_COACH=<slug>`),
    /// or that coach's lesson booking that many days ahead (also `PLAYERZ_COACH_BOOK=<days>`), #19.
    static var coaches: Bool { env["PLAYERZ_COACHES"] == "1" }
    /// `PLAYERZ_CREATE=1`: the «Създай» sheet on show, for a screenshot.
    static var create: Bool { env["PLAYERZ_CREATE"] == "1" }
    static var coach: String? { env["PLAYERZ_COACH"] }
    /// «Начало» scrolled to its clubs (`PLAYERZ_HOME=clubs`) or with «Филтри» open (`=filters`).
    static var home: String? { env["PLAYERZ_HOME"] }
    static var coachBook: Int? { env["PLAYERZ_COACH_BOOK"].flatMap(Int.init) }
    static var profile: Profile? { env["PLAYERZ_PROFILE"].flatMap(Profile.init(rawValue:)) }
    /// `PLAYERZ_EMPTY_END=1`: a scrolling empty state opens at its end, to
    /// photograph the last line above the tab bar at the largest text size.
    static var emptyStateEnd: Bool { env["PLAYERZ_EMPTY_END"] == "1" }
    /// `PLAYERZ_SCROLL_END=1`: every page opens at its end (`brandPage`), to
    /// see that its last row clears the tab bar.
    static var scrollEnd: Bool { env["PLAYERZ_SCROLL_END"] == "1" }
    /// `PLAYERZ_CHOOSE_LANGUAGE=en|bg`: chosen three seconds after launch, as
    /// the picker in «Профил» chooses it, to see the switch happen.
    static var chooseLanguage: String? { env["PLAYERZ_CHOOSE_LANGUAGE"] }
    /// Профил (#95): «Мачове» (`PLAYERZ_STATS=matches`), a sport
    /// (`PLAYERZ_STATS_SPORT=TENNIS`), the questionnaire open (`PLAYERZ_SURVEY=1`).
    static var statsMatches: Bool { env["PLAYERZ_STATS"] == "matches" }
    static var statsSport: String? { env["PLAYERZ_STATS_SPORT"] }
    static var survey: Bool { env["PLAYERZ_SURVEY"] == "1" }
    /// «Прогрес» scrolled to a section (`PLAYERZ_STATS_AT=performance|standing|sets|partners|rivals|activity`).
    static var statsAt: String? { env["PLAYERZ_STATS_AT"] }
    /// A venue opened at its court picker (`PLAYERZ_VENUE_AT=courts`).
    static var venueAt: String? { env["PLAYERZ_VENUE_AT"] }
    /// Every sport's drawn surface on one screen (`PLAYERZ_PITCHES=1`).
    static var pitches: Bool { env["PLAYERZ_PITCHES"] == "1" }
    /// A venue with its first hours picked (`PLAYERZ_PICK=3`), the summary
    /// open (`PLAYERZ_REVIEW=1`) and reserved (`PLAYERZ_RESERVE=1`: a DEBUG
    /// build on the local server only, as every DebugLaunch route).
    static var pick: Int? { env["PLAYERZ_PICK"].flatMap(Int.init) }
    static var review: Bool { env["PLAYERZ_REVIEW"] == "1" }
    static var reserve: Bool { env["PLAYERZ_RESERVE"] == "1" }
    /// `PLAYERZ_BOOKINGS=past`: Резервации opened on «Минали».
    static var bookingsPast: Bool { env["PLAYERZ_BOOKINGS"] == "past" }
    /// `PLAYERZ_BOOKINGS=cancelled`: Резервации opened on «Отменени» (#58).
    static var bookingsCancelled: Bool { env["PLAYERZ_BOOKINGS"] == "cancelled" }
    /// `PLAYERZ_OPEN=<what>`: a sheet or a form on the screen opened, for a
    /// screenshot. `invite` (a booking's players), `report` (a conversation),
    /// `review` (a played booking), `search` (the inbox, with `PLAYERZ_SEARCH`
    /// typed in), `card` (that search's first player), `bookings` (a venue's
    /// club bookings), `requests` (the inbox on «Заявки»). Nothing is sent.
    static var open: String? { env["PLAYERZ_OPEN"] }
    static var search: String? { env["PLAYERZ_SEARCH"] }
    #else
    static let credentials: (email: String, password: String)? = nil
    static let tab: Tab? = nil
    static let conversation: String? = nil
    static let gamesMine = false
    static let gamesTournaments = false
    static let tournament: String? = nil
    static let game: String? = nil
    static let gamesSheet: String? = nil
    static let tournamentDraw = false
    static let bookingGame: String? = nil
    static let club: String? = nil
    static let clubLeaderboard = false
    static let venue: String? = nil
    static let booking: String? = nil
    static let bookingPlayers: String? = nil
    static let invite: String? = nil
    static let coachArea: String? = nil
    static let notifications = false
    static let link: String? = nil
    static let result: String? = nil
    static let coaches = false
    static let create = false
    static let coach: String? = nil
    static let home: String? = nil
    static let coachBook: Int? = nil
    static let profile: Profile? = nil
    static let scrollEnd = false
    static let chooseLanguage: String? = nil
    static let statsMatches = false
    static let statsSport: String? = nil
    static let survey = false
    static let statsAt: String? = nil
    static let venueAt: String? = nil
    static let pitches = false
    static let pick: Int? = nil
    static let review = false
    static let reserve = false
    static let emptyStateEnd = false
    static let bookingsPast = false
    static let bookingsCancelled = false
    static let open: String? = nil
    static let search: String? = nil
    #endif

    /// An id from the environment, or nil for `first` or `last`: that one is
    /// picked from the list once it has loaded (`pick`), so a screenshot of a
    /// booking or a conversation needs no id looked up by hand.
    static func listed(_ id: String?) -> String? {
        id == "first" || id == "last" ? nil : id
    }

    @MainActor private static var picked: Set<String> = []

    /// The first or last of `ids` when the route `name`'s value asks for it,
    /// once per route, so going back does not reopen it.
    @MainActor static func pick(_ name: String, _ value: String?, from ids: [String]) -> String? {
        guard !picked.contains(name) else { return nil }
        let id: String? = switch value {
        case "first": ids.first
        case "last": ids.last
        default: nil
        }
        if id != nil { picked.insert(name) }
        return id
    }
}
