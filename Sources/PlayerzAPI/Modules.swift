import Foundation

/// Which product modules this server has switched on (`GET /config`,
/// RodnaPamet/projectZ#621; playerz-ios#16).
///
/// The web hides a module that is off, but a module's routes answer either
/// way, so the app has to hide it itself: production runs messaging and Игри
/// only, staging everything. `ranking` covers results, ratings, leaderboards
/// and tournaments.
public struct Modules: Sendable, Equatable {
    public var openPlay: Bool
    public var messaging: Bool
    public var coaches: Bool
    public var ranking: Bool

    /// Before the server has answered, or when it cannot be asked: what the
    /// app showed before #16, so a failed read never takes a working tab away.
    public static let unknown = Modules(openPlay: true, messaging: true, coaches: true, ranking: true)

    public init(openPlay: Bool, messaging: Bool, coaches: Bool, ranking: Bool) {
        self.openPlay = openPlay
        self.messaging = messaging
        self.coaches = coaches
        self.ranking = ranking
    }

    init(_ modules: Components.Schemas.AppModules) {
        self.init(
            openPlay: modules.openPlay,
            messaging: modules.messaging,
            coaches: modules.coaches,
            ranking: modules.ranking
        )
    }
}
