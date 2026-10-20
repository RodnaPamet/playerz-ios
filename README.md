# playerz-ios

The native iOS client for [playerz.bg](https://playerz.bg). Phase 1 of #167 in
`RodnaPamet/projectZ`: the API client and the session layer, no UI yet.

## What is here

| | |
|---|---|
| `Sources/PlayerzAPI/openapi.json` | the server's spec, put through `scripts/spec_for_swift.py` — never hand-edited |
| generated client | 23 operations, produced at build time by swift-openapi-generator |
| `TokenStore.swift` | the session actor: storage, refresh, coalescing |

## The spec is the contract, and it is only half-guarded

`openapi.json` is a copy of `openapi/playerz-v1.json` in the server repo, where
`tests/guardrails/openapi-coverage.test.ts` fails the build if a v1 route has no
matching path in the spec, or a path has no route. So the set of **endpoints**
here is trustworthy, and so are the operation names — that guardrail now also
requires a unique `operationId` on every operation, after four booking
operations were found without one and generated as
`post_sol_t_sol__lcub_slug_rcub__sol_bookings`.

It does **not** check schemas. The server's DTOs are TypeScript interfaces, not
runtime values, so nothing compares them to the spec. Treat generated
request/response *shapes* as unverified until something round-trips them against
a running server.

    make regenerate   # re-copy the spec and rebuild

The copy goes through `scripts/spec_for_swift.py`. The server writes "an X, or
null" as `oneOf: [{$ref: X}, {type: null}]`, which swift-openapi-generator
skips, taking the whole property out of the Swift type (#6). The script
rewrites each one into a form the generator reads as `X?`. The server's own
spec stays as it is, because that form is the correct JSON Schema. CI applies
the same rewrite to the server's spec before comparing it with this copy, and a
nullable shape the script cannot rewrite stops both.

## Building and testing

    make build
    make test

`make test`, not `swift test`. `xcrun -f swift` on this machine resolves to
CommandLineTools, whose swiftpm knows nothing about `Testing.framework` — a bare
`swift test` fails to compile, and then fails to load. The Makefile supplies the
three flags that fix it.

## The session layer

`TokenStore` is an actor, and the tests that matter are the concurrency ones.

Two behaviours are worth knowing before changing anything:

**A null `refreshToken` means keep the one you have.** `POST /auth/refresh`
returns `refreshToken: null` when the presented token is inside the server's
rotation grace window, or when its compare-and-swap lost to a concurrent
refresh. Both are ordinary concurrency outcomes with a perfectly good access
token attached. Storing the null throws away a working refresh token and signs
the user out at next launch — only under load.

**State is re-checked after the refresh await.** An actor releases isolation at
every suspension, so "there is still a session" stops being true the moment the
refresh is awaited. Signing out mid-refresh used to be undone by the refresh
completing; a generation counter now makes a stale refresh lose to both a
sign-out and a newer sign-in.

## Looking at a screen on the simulator

A DEBUG build reads where to open from its environment (`DebugLaunch.swift`,
compiled out of release builds). Run the server locally with password sign-in
(`TEST_PASSWORD_SIGN_IN=1`, `DEPLOY_ENV=test`), then:

    SIMCTL_CHILD_PLAYERZ_SERVER_URL=http://localhost:3100 \
    SIMCTL_CHILD_PLAYERZ_EMAIL=… SIMCTL_CHILD_PLAYERZ_PASSWORD=… \
    SIMCTL_CHILD_PLAYERZ_TAB=games \
    xcrun simctl launch booted bg.playerz.app -AppleLanguages "(bg)"
    xcrun simctl io booted screenshot screen.png

`PLAYERZ_TAB` is `play`, `games`, `messages` or `profile`. `PLAYERZ_GAMES=mine`
opens «Моите заявки», and `PLAYERZ_CONVERSATION=<id>` opens a conversation.

The server URL is the **origin**: the generated client adds `/api/v1` itself,
so `…/api/v1` as the server makes every call `/api/v1/api/v1/…` and a 404.
Plain `http://localhost` is allowed by App Transport Security; a device needs a
tunnel.

## Not done yet

No UI and no push registration yet. v1 is scoped to **discovery + booking, no
payments**, so Stripe Connect and the SCA flow are deliberately out.

`TokenPersistence` has a real Keychain implementation now. Two attributes carry
the whole security posture and both are pinned by tests:
`AfterFirstUnlock` (so a background push can refresh with the phone locked —
`WhenUnlocked` silently breaks that) and `ThisDeviceOnly` (so a refresh token
never rides an iCloud backup onto a second device as a live session).
