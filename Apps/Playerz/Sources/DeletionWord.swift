import Foundation

/// The word that confirms deleting the account: the web's rule
/// (`src/lib/account/confirm-word.ts`). Either language's word whatever the
/// app's language, since a Bulgarian reader is often on a Latin keyboard; case
/// and the spaces around it do not matter.
enum DeletionWord {
    static let words: Set<String> = ["изтрий", "delete"]

    static func confirms(_ typed: String) -> Bool {
        let word = typed.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .lowercased()
        return words.contains(word)
    }
}
