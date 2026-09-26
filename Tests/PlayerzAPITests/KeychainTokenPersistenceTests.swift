import Foundation
import Security
import Testing

@testable import PlayerzAPI

/// Whether this process can actually reach a Keychain.
///
/// It works in an unsigned binary on macOS, and does NOT work in every CI
/// environment — a sandboxed runner returns `errSecMissingEntitlement`. These
/// tests skip there rather than failing, because a red suite that means "this
/// machine has no Keychain" trains people to ignore red suites.
private let keychainAvailable: Bool = {
    let probe: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "bg.playerz.availability-probe",
        kSecAttrAccount as String: "probe",
        kSecValueData as String: Data("x".utf8),
    ]
    SecItemDelete(probe as CFDictionary)
    let status = SecItemAdd(probe as CFDictionary, nil)
    SecItemDelete(probe as CFDictionary)
    return status == errSecSuccess
}()

/// A service name unique to each test, because Swift Testing runs them in
/// parallel and they would otherwise fight over one Keychain item.
private func isolatedStore(_ name: String = #function) -> KeychainTokenPersistence {
    KeychainTokenPersistence(service: "bg.playerz.test.\(name).\(UUID().uuidString)")
}

private func sample(access: String = "access-1", refresh: String = "refresh-1") -> Tokens {
    Tokens(
        accessToken: access,
        accessExpiresAt: Date(timeIntervalSince1970: 1_800_000_000),
        refreshToken: refresh,
        refreshExpiresAt: Date(timeIntervalSince1970: 1_802_592_000)
    )
}

@Suite("KeychainTokenPersistence", .enabled(if: keychainAvailable, "no Keychain in this environment"))
struct KeychainTokenPersistenceTests {
    @Test("a saved session comes back exactly")
    func roundTrip() throws {
        let store = isolatedStore()
        defer { try? store.clear() }

        try store.save(sample())
        #expect(try store.load() == sample())
    }

    @Test("saving twice UPDATES rather than failing or duplicating")
    func saveIsIdempotent() throws {
        // SecItemAdd on an existing item returns errSecDuplicateItem instead of
        // replacing it. An add-first implementation therefore writes the FIRST
        // session and silently keeps it forever — every refresh after that is
        // stored nowhere, and the app reads a stale token at next launch.
        let store = isolatedStore()
        defer { try? store.clear() }

        try store.save(sample(access: "first", refresh: "r1"))
        try store.save(sample(access: "second", refresh: "r2"))

        #expect(try store.load()?.accessToken == "second")
        #expect(try store.load()?.refreshToken == "r2")
    }

    @Test("an absent item loads as nil, not as an error")
    func absentIsNil() throws {
        // A fresh install and a signed-out user are the same state, and neither
        // is a failure. Throwing here would make the first launch a crash.
        #expect(try isolatedStore().load() == nil)
    }

    @Test("clear removes the session, and clearing nothing is not an error")
    func clearIsSafe() throws {
        let store = isolatedStore()
        try store.save(sample())
        try store.clear()

        #expect(try store.load() == nil)
        // Signing out twice, or clearing after a failed save, must not throw.
        #expect(throws: Never.self) { try store.clear() }
    }

    @Test("an unreadable item signs the user out rather than breaking every launch")
    func corruptDataLoadsAsNil() throws {
        // A format change or a corrupt item. Returning nil costs one sign-in;
        // throwing would fail load() on every launch until reinstall, with no
        // way for the user to recover.
        let store = isolatedStore()
        defer { try? store.clear() }

        var insert = store.lookupQuery
        insert[kSecValueData as String] = Data("not json".utf8)
        insert[kSecAttrAccessible as String] = store.accessibility
        SecItemDelete(store.lookupQuery as CFDictionary)
        #expect(SecItemAdd(insert as CFDictionary, nil) == errSecSuccess)

        #expect(try store.load() == nil)
    }
}

/// Asserted without touching the Keychain, so they run everywhere — including
/// the CI where the suite above skips.
@Suite("Keychain attributes")
struct KeychainAttributeTests {
    @Test("the item is readable after first unlock, so background refresh works")
    func accessibleAfterFirstUnlock() {
        // Not `WhenUnlocked`. A push arrives with the phone in a pocket, the app
        // wakes in the background and needs the refresh token; under
        // `WhenUnlocked` that read fails and the session looks expired to code
        // that cannot tell the difference.
        let a = KeychainTokenPersistence().accessibility
        #expect(a == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        #expect(a != kSecAttrAccessibleWhenUnlocked)
        #expect(a != kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    @Test("the item never leaves this device")
    func thisDeviceOnly() {
        // Without ThisDeviceOnly the refresh token syncs through iCloud Keychain
        // and lands in an encrypted backup — so restoring that backup onto a
        // second device carries a LIVE SESSION with it. A refresh token is a
        // bearer credential with a thirty-day life.
        // The two accessibility values that DO sync. Everything else Apple
        // offers is already a ThisDeviceOnly variant.
        let syncable: Set<String> = [
            kSecAttrAccessibleWhenUnlocked as String,
            kSecAttrAccessibleAfterFirstUnlock as String,
        ]
        #expect(!syncable.contains(KeychainTokenPersistence().accessibility as String))

        // And positively, so the test cannot pass by naming the wrong constant.
        #expect(
            (KeychainTokenPersistence().accessibility as String)
                == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        )
    }

    @Test("the lookup query does NOT pin accessibility")
    func lookupIgnoresAccessibility() {
        // A lookup that specifies accessibility fails to find an item stored
        // under a different one. That turns a future policy change into a
        // silent sign-out for every existing user instead of a migration.
        let keys = KeychainTokenPersistence().lookupQuery.keys.map { $0 }
        #expect(!keys.contains(kSecAttrAccessible as String))
    }
}
