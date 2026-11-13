import Foundation
import PlayerzAPI

/// A place's word in the app's language, in the forms a sentence needs
/// (PlaceWord, owner 2026-11-13): «Корт» on a label, «корт» inside a
/// sentence, «кортът» as its subject, «корта» after a preposition, and
/// «кортове» for several; «закрит/закрито/закрита» agreeing with it.
enum PlaceText {
    nonisolated static func label(_ word: PlaceWord) -> String { localized(key: "place.\(word.rawValue)") }
    nonisolated static func lower(_ word: PlaceWord) -> String { localized(key: "place.\(word.rawValue).lower") }
    nonisolated static func the(_ word: PlaceWord) -> String { localized(key: "place.\(word.rawValue).the") }
    nonisolated static func of(_ word: PlaceWord) -> String { localized(key: "place.\(word.rawValue).of") }
    nonisolated static func plural(_ word: PlaceWord) -> String { localized(key: "place.\(word.rawValue).plural") }

    /// «Закрит корт», «Открито игрище», «Закрита маса».
    nonisolated static func roof(_ word: PlaceWord, indoor: Bool) -> String {
        localized(key: "place.\(indoor ? "indoor" : "outdoor").\(word.gender.rawValue)")
    }

    /// The label for one sport's place.
    nonisolated static func label(sport: String) -> String { label(PlaceWord.of(sport)) }
}
