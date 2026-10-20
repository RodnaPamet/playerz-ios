import Foundation
import Testing

@testable import PlayerzAPI

/// The app's strings (playerz-ios#13): it shows whichever language iOS picks,
/// so every string must exist in both, and every key the code asks for must
/// be in the catalogue. A missing one shows its raw key on screen.
@Suite("The string catalogue")
struct CatalogueTests {
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func catalogue() throws -> [String: Any] {
        let url = root.appending(path: "Apps/Playerz/Resources/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let file = try #require(object as? [String: Any])
        return try #require(file["strings"] as? [String: Any])
    }

    /// The text of one language: its string, or every plural form's.
    private static func texts(_ localization: Any?) -> [String] {
        guard let localization = localization as? [String: Any] else { return [] }
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return [value]
        }
        let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
        return plural.values.compactMap { (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    @Test("every string is in Bulgarian and English")
    func bothLanguages() throws {
        var missing: [String] = []
        for (key, entry) in try Self.catalogue() {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for language in ["bg", "en"] where Self.texts(localizations[language]).allSatisfy(\.isEmpty) {
                missing.append("\(key) [\(language)]")
            }
        }
        #expect(missing.sorted() == [])
    }

    @Test("every key the app asks for is in the catalogue")
    func keysExist() throws {
        let catalogue = try Self.catalogue()
        // A key's interpolations, and the catalogue's format specifiers, as one placeholder.
        let known = Set(catalogue.keys.map {
            $0.replacingOccurrences(of: #"%(\d+\$)?(lld|@|d)"#, with: "{}", options: .regularExpression)
        })
        let literal = try NSRegularExpression(pattern: #"String\(localized: "((?:[^"\\]|\\\((?:[^()]|\([^()]*\))*\))*)""#)
        let interpolation = try NSRegularExpression(pattern: #"\\\((?:[^()]|\([^()]*\))*\)"#)
        let sources = Self.root.appending(path: "Apps/Playerz/Sources")
        var missing: [String] = []
        for case let file as URL in FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) ?? .init()
        where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in literal.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let key = String(text[range])
                let normalised = interpolation.stringByReplacingMatches(
                    in: key, range: NSRange(key.startIndex..., in: key), withTemplate: "{}"
                )
                if !known.contains(normalised) { missing.append("\(file.lastPathComponent): \(key)") }
            }
        }
        #expect(missing.sorted() == [])
    }

    @Test("the account's code for the app's language")
    func languageCode() {
        #expect(AppLanguage.code(for: "en") == .en)
        #expect(AppLanguage.code(for: "en-GB") == .en)
        #expect(AppLanguage.code(for: "bg") == .bg)
        #expect(AppLanguage.code(for: nil) == .bg)
        #expect(AppLanguage.code(for: "de") == .bg)
    }
}
