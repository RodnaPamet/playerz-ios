import Foundation

/// The terms of use and privacy policy this account has not accepted at the
/// version in force (`GET /me/legal-acceptance`, playerz-ios#10).
///
/// The server never holds the API back for them: a native client is expected
/// to show its own step while something is owed, as the web sends a person
/// to `/start/terms`. While no text is published, nothing is ever owed.
public struct OwedTexts: Sendable, Equatable {
    /// One text: `terms` or `privacy`, and the version in force.
    public struct Text: Sendable, Equatable, Identifiable {
        public let id: String
        public let version: String?
    }

    public let texts: [Text]
    public var isEmpty: Bool { texts.isEmpty }

    init(_ standing: Components.Schemas.LegalStanding) {
        texts = standing.due.map { text in
            switch text {
            case .terms: Text(id: "terms", version: standing.current.terms)
            case .privacy: Text(id: "privacy", version: standing.current.privacy)
            }
        }
    }
}

/// Why the texts could not be read or accepted.
public enum LegalStepError: Error, Equatable {
    case notSignedIn
    /// The default mutation budget, 60 a minute.
    case rateLimited
    /// Anything else, offline included.
    case failed
}
