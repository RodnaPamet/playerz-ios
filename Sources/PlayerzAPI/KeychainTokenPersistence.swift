import Foundation
import Security

/// Stores the session in the Keychain.
///
/// ═══ THE TWO ATTRIBUTE CHOICES ARE THE WHOLE SECURITY DESIGN ═══
///
/// Everything else here is plumbing. These two decide what an attacker with the
/// device, or with a backup of it, can do.
///
/// **`kSecAttrAccessibleAfterFirstUnlock`**, not `WhenUnlocked`. A push arrives
/// while the phone is in a pocket; the app wakes in the background, needs the
/// refresh token, and under `WhenUnlocked` the read fails. The session then
/// looks expired to code that cannot tell the difference, and `TokenStore` has
/// no tokens to refresh with. `AfterFirstUnlock` keeps the item readable once
/// the user has unlocked at least once since boot — which is the weakest
/// condition that still works, and strictly stronger than the old `Always`.
///
/// **`ThisDeviceOnly`**, so the item never leaves this handset. Without it the
/// refresh token syncs through iCloud Keychain and lands in an encrypted
/// backup, so restoring that backup onto a second device carries a LIVE SESSION
/// with it — signed in as the user, on hardware they may no longer own. A
/// refresh token is a bearer credential with a thirty-day life; it is not the
/// kind of thing to replicate for convenience.
///
/// ═══ WHY THE PROTOCOL EXISTS ═══
///
/// `TokenPersistence` is a protocol because the refresh logic is what is worth
/// testing and the Keychain is the worst possible place to test it: it needs
/// entitlements, it behaves differently on a simulator, and it fails in CI for
/// reasons that have nothing to do with the code. The in-memory double carries
/// the unit tests; this type carries the app.
public struct KeychainTokenPersistence: TokenPersistence {
    private let service: String
    private let account: String

    public init(service: String = "bg.playerz.app.session", account: String = "tokens") {
        self.service = service
        self.account = account
    }

    /// Identifies the one item. Deliberately NOT including the accessibility
    /// attribute: a lookup that specifies it fails to find an item stored under
    /// a different one, which turns a changed policy into a silent sign-out
    /// instead of a migration.
    var lookupQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// The attributes written on add. See the type docs — these two lines are
    /// the security posture.
    var accessibility: CFString { kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }

    public func load() throws -> Tokens? {
        var query = lookupQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        // Not an error: a fresh install, or a user who signed out.
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError(status: status, operation: "load")
        }

        do {
            return try JSONDecoder().decode(StoredTokens.self, from: data).asTokens
        } catch {
            // Unreadable rather than absent — a format change, or a corrupt
            // item. Returning nil signs the user out, which is recoverable;
            // throwing here would fail every launch until they reinstall.
            return nil
        }
    }

    public func save(_ tokens: Tokens) throws {
        let data = try JSONEncoder().encode(StoredTokens(tokens))

        // Update first: SecItemAdd on an existing item returns
        // errSecDuplicateItem rather than replacing it, so add-then-fallback
        // would write the new session only on the very first save.
        let updated = SecItemUpdate(
            lookupQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else {
            throw KeychainError(status: updated, operation: "save/update")
        }

        var insert = lookupQuery
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = accessibility

        let added = SecItemAdd(insert as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw KeychainError(status: added, operation: "save/add")
        }
    }

    public func clear() throws {
        let status = SecItemDelete(lookupQuery as CFDictionary)
        // Deleting what is not there is the desired end state, not a failure.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status, operation: "clear")
        }
    }
}

public struct KeychainError: Error, CustomStringConvertible {
    public let status: OSStatus
    public let operation: String

    public var description: String {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "Keychain \(operation) failed: \(detail) (OSStatus \(status))"
    }
}

/// The on-disk shape, kept separate from `Tokens` on purpose.
///
/// `Tokens` is free to change for the app's convenience; this is a storage
/// format that has to survive an app update with a session already in the
/// Keychain. Dates are epoch seconds rather than `Date`'s default encoding,
/// which is a reference-date Double and much easier to get subtly wrong.
private struct StoredTokens: Codable {
    let accessToken: String
    let accessExpiresAt: TimeInterval
    let refreshToken: String
    let refreshExpiresAt: TimeInterval

    init(_ t: Tokens) {
        accessToken = t.accessToken
        accessExpiresAt = t.accessExpiresAt.timeIntervalSince1970
        refreshToken = t.refreshToken
        refreshExpiresAt = t.refreshExpiresAt.timeIntervalSince1970
    }

    var asTokens: Tokens {
        Tokens(
            accessToken: accessToken,
            accessExpiresAt: Date(timeIntervalSince1970: accessExpiresAt),
            refreshToken: refreshToken,
            refreshExpiresAt: Date(timeIntervalSince1970: refreshExpiresAt)
        )
    }
}
