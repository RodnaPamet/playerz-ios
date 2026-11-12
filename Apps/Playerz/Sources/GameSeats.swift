import Foundation
import PlayerzAPI

extension GameSeats {
    /// The court of `game`, with pictures read from the server the app is signed in to.
    init(game: Components.Schemas.OpenGame, server: String) {
        self.init(game: game, picture: { GameText.picture($0, server: server) })
    }
}
