import Foundation
import PlayerzAPI

/// Names in a draw (#22).
enum DrawText {
    /// An entry's players: «Иван и Петър».
    static func entry(_ entry: Components.Schemas.DrawEntry) -> String {
        let names = entry.players.map(TournamentText.person).formatted(.list(type: .and))
        return entry.withdrawn ? "\(names) (\(String(localized: "tournaments.draw.withdrawn")))" : names
    }

    /// A side: its entry, or both for Americano and Mexicano; «Предстои» until known.
    static func side(_ first: Components.Schemas.DrawEntry?, _ second: Components.Schemas.DrawEntry?) -> String {
        guard let first else { return String(localized: "tournaments.draw.tbd") }
        guard let second else { return entry(first) }
        return "\(entry(first)) / \(entry(second))"
    }
}
