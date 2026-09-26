import Foundation

public enum TokenStoreError: Error, Equatable {
    /// The session was signed out, or replaced by a newer one, while a refresh
    /// was in flight. The refreshed tokens are deliberately discarded.
    case sessionChangedDuringRefresh
}

/// The credentials a signed-in session holds.
public struct Tokens: Sendable, Equatable {
    public var accessToken: String
    public var accessExpiresAt: Date
    public var refreshToken: String
    public var refreshExpiresAt: Date

    public init(accessToken: String, accessExpiresAt: Date, refreshToken: String, refreshExpiresAt: Date) {
        self.accessToken = accessToken
        self.accessExpiresAt = accessExpiresAt
        self.refreshToken = refreshToken
        self.refreshExpiresAt = refreshExpiresAt
    }
}

/// Where tokens live between launches.
///
/// Deliberately a protocol: the Keychain is awkward in unit tests and absent on
/// Linux, and the refresh logic is the part worth testing.
public protocol TokenPersistence: Sendable {
    func load() throws -> Tokens?
    func save(_ tokens: Tokens) throws
    func clear() throws
}

/// Holds the session and performs refreshes, one at a time.
///
/// ═══ WHY AN ACTOR, AND WHY THIS IS NOT OVER-ENGINEERING ═══
///
/// A screen that fires three requests at once, all with an expired access
/// token, would refresh three times. The server is explicitly built for that
/// and answers it in a way a naive client gets WRONG — see `applyRefreshed`.
/// Serialising here means the burst never happens in the first place; handling
/// it correctly when it does is the belt to that braces.
public actor TokenStore {
    private let persistence: any TokenPersistence
    private var tokens: Tokens?
    private var inFlight: Task<Tokens, Error>?

    /// Bumped by every write, including sign-out.
    ///
    /// This exists only to be compared across a suspension. An actor releases
    /// its isolation at every `await`, so anything `validAccessToken` believed
    /// before awaiting a refresh — above all "there is still a session" — is
    /// no longer known to be true afterwards.
    private var generation: UInt64 = 0

    /// Refresh this long before the access token actually expires, so a request
    /// cannot be issued with a token that dies in flight.
    private let skew: TimeInterval

    public init(persistence: any TokenPersistence, skew: TimeInterval = 60) {
        self.persistence = persistence
        self.skew = skew
        self.tokens = try? persistence.load()
    }

    public var current: Tokens? { tokens }

    public func set(_ tokens: Tokens) throws {
        self.tokens = tokens
        generation &+= 1
        try persistence.save(tokens)
    }

    public func signOut() throws {
        tokens = nil
        // Redundant today, and deliberately kept: no test can distinguish it,
        // because sign-out is already caught by the `tokens != nil` half of the
        // guard, and any sign-in that follows bumps the counter through `set`.
        // It is here so the invariant is "every state change bumps the
        // generation" with no exceptions — an exception is what someone would
        // have to notice before adding a fourth mutator that needs it.
        generation &+= 1
        inFlight?.cancel()
        inFlight = nil
        try persistence.clear()
    }

    /// Fold a refresh response into the stored session.
    ///
    /// ═══ THE NULL REFRESH TOKEN IS THE WHOLE POINT OF THIS METHOD ═══
    ///
    /// `POST /auth/refresh` returns `refreshToken: null` in two REAL cases,
    /// both verified in the server's `rotateRefreshToken`:
    ///
    ///   1. the presented token is inside the rotation grace window — it
    ///      rotates nothing and returns no new token, deliberately, because
    ///      rotating again is what turns one client's burst into a storm;
    ///   2. the compare-and-swap lost to a concurrent refresh that got there
    ///      first.
    ///
    /// Both are CONCURRENCY outcomes, not failures — the access token in the
    /// same response is perfectly good. A client that stores the null discards
    /// a working refresh token and signs the user out at the next launch, and
    /// it does so only under load, which is the hardest possible bug to catch.
    ///
    /// So: null means KEEP WHAT WE HAVE.
    public func applyRefreshed(
        accessToken: String,
        accessExpiresAt: Date,
        refreshToken newRefresh: String?,
        refreshExpiresAt: Date
    ) throws {
        guard let existing = tokens else { return }
        try set(
            Tokens(
                accessToken: accessToken,
                accessExpiresAt: accessExpiresAt,
                refreshToken: newRefresh ?? existing.refreshToken,
                refreshExpiresAt: refreshExpiresAt
            )
        )
    }

    /// A token good for the next request, refreshing only if it has to.
    ///
    /// Concurrent callers share ONE refresh: the first starts it, the rest
    /// await the same task.
    public func validAccessToken(refreshing refresh: @Sendable @escaping (String) async throws -> Tokens) async throws -> String? {
        guard let held = tokens else { return nil }

        if held.accessExpiresAt.timeIntervalSinceNow > skew {
            return held.accessToken
        }

        if let running = inFlight {
            return try await running.value.accessToken
        }

        let startedAt = generation
        let task = Task<Tokens, Error> { [held] in
            try await refresh(held.refreshToken)
        }
        inFlight = task
        defer { inFlight = nil }

        let refreshed = try await task.value

        // ═══ THE ACTOR WAS NOT HELD ACROSS THAT AWAIT ═══
        //
        // Anything could have run while this was suspended, and the one that
        // matters is `signOut`. Writing the result back unconditionally signs a
        // user who just signed out BACK IN, with a token that outlives their
        // intent and survives the next launch — and it only happens when a
        // refresh is in flight at that moment, so it would never show up by
        // hand.
        //
        // The generation check also covers a fresh sign-in landing mid-refresh:
        // that session is newer and must not be clobbered by this stale one.
        guard generation == startedAt, tokens != nil else {
            throw TokenStoreError.sessionChangedDuringRefresh
        }

        try set(refreshed)
        return refreshed.accessToken
    }
}
