import Foundation

/// A code sent to a phone (`POST /me/phone/start`, playerz-ios#11).
public struct PhoneCode: Sendable, Equatable {
    /// The number the code went to, its middle hidden (`+35988*****56`).
    public let maskedNumber: String
    /// Sent back unchanged with the code: it ties the code to this account and
    /// this number, for ten minutes. Opaque.
    public let challenge: String
}

/// Why the phone step stopped, by the server's code (#500).
public enum PhoneStepError: Error, Equatable {
    /// Not a number that can receive an SMS code.
    case invalidNumber
    /// Not the code.
    case wrongCode
    /// The code expired or was used, or a newer one was asked for.
    case expiredCode
    /// The number already confirms another account.
    case numberInUse
    case rateLimited
    /// The SMS service is not set up or did not answer; nothing was sent.
    case unavailable
    case notSignedIn
    /// Anything else, offline included.
    case failed
}
