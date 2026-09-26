import Foundation
import Testing

@testable import PlayerzAPI

/// An in-memory stand-in for the Keychain. The refresh logic is what is worth
/// testing; the Keychain is awkward in a unit test and is not the risk.
final class MemoryPersistence: TokenPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Tokens?
    private(set) var saves = 0

    init(_ initial: Tokens? = nil) { stored = initial }

    func load() throws -> Tokens? { lock.withLock { stored } }
    func save(_ tokens: Tokens) throws { lock.withLock { stored = tokens; saves += 1 } }
    func clear() throws { lock.withLock { stored = nil } }
    var peek: Tokens? { lock.withLock { stored } }
}

private func tokens(
    access: String = "access-1",
    accessIn: TimeInterval = 900,
    refresh: String = "refresh-1",
    refreshIn: TimeInterval = 30 * 24 * 3600
) -> Tokens {
    Tokens(
        accessToken: access,
        accessExpiresAt: Date().addingTimeInterval(accessIn),
        refreshToken: refresh,
        refreshExpiresAt: Date().addingTimeInterval(refreshIn)
    )
}

@Suite("TokenStore")
struct TokenStoreTests {
    @Test("a null refreshToken keeps the one we already hold")
    func nullRefreshKeepsExisting() async throws {
        // The server returns refreshToken: null when the presented token is
        // inside the rotation grace window, or when the compare-and-swap lost
        // to a concurrent refresh. Both are concurrency outcomes with a
        // perfectly good access token attached. Storing the null would discard
        // a working refresh token and sign the user out at next launch.
        let p = MemoryPersistence(tokens())
        let store = TokenStore(persistence: p)

        try await store.applyRefreshed(
            accessToken: "access-2",
            accessExpiresAt: Date().addingTimeInterval(900),
            refreshToken: nil,
            refreshExpiresAt: Date().addingTimeInterval(30 * 24 * 3600)
        )

        let now = await store.current
        #expect(now?.accessToken == "access-2")
        #expect(now?.refreshToken == "refresh-1", "the refresh token must survive a null")
    }

    @Test("a rotated refreshToken replaces the old one")
    func rotationReplaces() async throws {
        let store = TokenStore(persistence: MemoryPersistence(tokens()))

        try await store.applyRefreshed(
            accessToken: "access-2",
            accessExpiresAt: Date().addingTimeInterval(900),
            refreshToken: "refresh-2",
            refreshExpiresAt: Date().addingTimeInterval(30 * 24 * 3600)
        )

        #expect(await store.current?.refreshToken == "refresh-2")
    }

    @Test("a live access token is not refreshed")
    func liveTokenIsReused() async throws {
        let store = TokenStore(persistence: MemoryPersistence(tokens(accessIn: 900)))
        let refreshes = Counter()

        let token = try await store.validAccessToken { _ in
            await refreshes.bump()
            return tokens(access: "should-not-happen")
        }

        #expect(token == "access-1")
        #expect(await refreshes.value == 0)
    }

    @Test("a token inside the skew window is treated as expired")
    func skewForcesRefresh() async throws {
        // 30s of life left against a 60s skew: still valid by the clock, but it
        // could die mid-flight, which surfaces as a spurious 401.
        let store = TokenStore(persistence: MemoryPersistence(tokens(accessIn: 30)))

        let token = try await store.validAccessToken { _ in tokens(access: "access-2") }
        #expect(token == "access-2")
    }

    @Test("concurrent callers share ONE refresh", .timeLimit(.minutes(1)))
    func concurrentRefreshCoalesces() async throws {
        // Three requests on one screen, all with an expired token. Without
        // coalescing this is three refreshes — which is exactly the burst the
        // server's grace window exists to absorb, and exactly what produces the
        // null refreshToken this suite's first test is about. Better not to
        // create the burst at all.
        let store = TokenStore(persistence: MemoryPersistence(tokens(accessIn: -10)))
        let refreshes = Counter()

        let results = try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await store.validAccessToken { _ in
                        await refreshes.bump()
                        try? await Task.sleep(nanoseconds: 20_000_000)
                        return tokens(access: "access-2")
                    }
                }
            }
            var out: [String?] = []
            for try await r in group { out.append(r) }
            return out
        }

        #expect(results.allSatisfy { $0 == "access-2" })
        #expect(await refreshes.value == 1, "eight callers must cause one refresh")
    }

    @Test("no session means no token and no refresh attempt")
    func signedOutReturnsNil() async throws {
        let store = TokenStore(persistence: MemoryPersistence(nil))
        let refreshes = Counter()

        let token = try await store.validAccessToken { _ in
            await refreshes.bump()
            return tokens()
        }

        #expect(token == nil)
        #expect(await refreshes.value == 0, "refreshing without a session would 401 for nothing")
    }

    @Test("signing out clears persistence, not just memory")
    func signOutClearsDisk() async throws {
        let p = MemoryPersistence(tokens())
        let store = TokenStore(persistence: p)

        try await store.signOut()

        #expect(await store.current == nil)
        #expect(p.peek == nil, "a token left on disk comes back at next launch")
    }

    @Test("applyRefreshed on a signed-out store does not resurrect a session")
    func applyAfterSignOutIsInert() async throws {
        // A refresh in flight when the user signs out must not write the
        // session back.
        let p = MemoryPersistence(tokens())
        let store = TokenStore(persistence: p)
        try await store.signOut()

        try await store.applyRefreshed(
            accessToken: "access-2",
            accessExpiresAt: Date().addingTimeInterval(900),
            refreshToken: "refresh-2",
            refreshExpiresAt: Date().addingTimeInterval(900)
        )

        #expect(await store.current == nil)
        #expect(p.peek == nil)
    }
}

actor Counter {
    private(set) var value = 0
    func bump() { value += 1 }
}

/// Holds a refresh open, and lets the test know when it has genuinely begun.
///
/// The second half is the point. Sleeping for "long enough" that a refresh has
/// started is a guess, and a guess that gets worse on a loaded CI box — the
/// kind of test that passes a thousand times and then blocks a merge for
/// reasons nobody can reproduce. `waitUntilStarted()` observes the thing
/// directly instead, so the ordering is a fact rather than a hope.
actor Gate {
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private var started = false

    /// Called from INSIDE the refresh closure: announce, then block.
    func arrive() async {
        started = true
        for w in startWaiters { w.resume() }
        startWaiters.removeAll()

        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    /// Returns once a refresh is genuinely in flight.
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        released = true
        for w in releaseWaiters { w.resume() }
        releaseWaiters.removeAll()
    }
}

@Suite("TokenStore reentrancy")
struct TokenStoreReentrancyTests {
    @Test("signing out during an in-flight refresh is not undone by it", .timeLimit(.minutes(1)))
    func signOutDuringRefreshWins() async throws {
        // The actor suspends across `await task.value`. Everything it believed
        // about its own state before that await is stale afterwards — and
        // "there is a session" is one of those beliefs. If the refresh writes
        // its result back unconditionally, signing out mid-refresh silently
        // signs the user back in, with a token that outlives their intent.
        let p = MemoryPersistence(tokens(accessIn: -10))
        let store = TokenStore(persistence: p)
        let gate = Gate()

        let refreshing = Task {
            try await store.validAccessToken { _ in
                await gate.arrive()
                return tokens(access: "access-2", refresh: "refresh-2")
            }
        }

        await gate.waitUntilStarted()
        try await store.signOut()
        await gate.release()
        _ = try? await refreshing.value

        #expect(await store.current == nil, "the refresh must not resurrect a signed-out session")
        #expect(p.peek == nil, "and must not leave a token on disk")
    }

    @Test("a NEW session signed in mid-refresh is not clobbered by the old one", .timeLimit(.minutes(1)))
    func newSessionSurvivesStaleRefresh() async throws {
        // The sibling test below covers signing OUT mid-refresh, where the
        // session goes to nil. This is the other half and it is sneakier: sign
        // out and straight back in — or a second account signs in — and by the
        // time the stale refresh resumes there IS a session again, so a
        // nil-check waves it through. The stale tokens then overwrite a newer,
        // valid session, and the user is silently operating as whoever was
        // signed in before.
        //
        // This is what the generation counter is for. A nil-check alone cannot
        // see it, because nothing is nil.
        let p = MemoryPersistence(tokens(accessIn: -10))
        let store = TokenStore(persistence: p)
        let gate = Gate()

        let refreshing = Task {
            try await store.validAccessToken { _ in
                await gate.arrive()
                return tokens(access: "stale-access", refresh: "stale-refresh")
            }
        }
        await gate.waitUntilStarted()

        try await store.set(tokens(access: "new-access", refresh: "new-refresh"))
        await gate.release()
        _ = try? await refreshing.value

        #expect(await store.current?.accessToken == "new-access")
        #expect(await store.current?.refreshToken == "new-refresh")
        #expect(p.peek?.refreshToken == "new-refresh", "the stale refresh must not reach disk")
    }

    @Test("a refresh result is persisted even if the caller that started it goes away", .timeLimit(.minutes(1)))
    func persistenceSurvivesInitiatorCancellation() async throws {
        // Coalescing means one caller starts the refresh and the others await
        // it. If only the STARTER writes the result, a starter that is
        // cancelled — a screen dismissed mid-request, which is routine — leaves
        // every other caller holding a fresh access token that was never
        // stored. Next launch reads the old one.
        let p = MemoryPersistence(tokens(accessIn: -10))
        let store = TokenStore(persistence: p)
        let gate = Gate()

        let starter = Task {
            try await store.validAccessToken { _ in
                await gate.arrive()
                return tokens(access: "access-2", refresh: "refresh-2")
            }
        }
        await gate.waitUntilStarted()

        let waiter = Task {
            try await store.validAccessToken { _ in
                Issue.record("the waiter must not start a second refresh")
                return tokens()
            }
        }
        // No deterministic signal exists for "the waiter has reached the
        // coalescing branch", so this one yield remains a guess — but a wrong
        // guess makes the waiter start its own refresh, which the Issue.record
        // above turns into a FAILURE rather than a false pass.
        try await Task.sleep(nanoseconds: 20_000_000)

        starter.cancel()
        await gate.release()
        _ = try? await starter.value
        _ = try? await waiter.value

        #expect(p.peek?.accessToken == "access-2", "the refreshed session must reach disk")
        #expect(p.peek?.refreshToken == "refresh-2")
    }
}
