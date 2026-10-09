# Test coverage and evidence

`LatestVerification` executes production core/adapter code with controlled
fixtures on macOS 27. It performs no root installation and no user-app update.
`LatestCoreTests` provides the Xcode Swift Testing suite; `LatestUITests` uses
the real native SwiftUI views with an isolated debug fixture inventory.

| Behaviour / audit finding | Automated evidence | Remaining acceptance |
|---|---|---|
| A01 shell interpolation | Literal quote/metacharacter argument process test | None for removed shell sink |
| A02 unrestricted root request | Numeric-ID/duplicate/path policy; root payload, scripts and traversal tests | Native signed peer, file-race and positive package tests |
| A03 dependency updates | Exact distribution digest and source revision, compiled Sparkle 2.10 / mas v7 | Controlled signed Sparkle update |
| A04 versions | Equality/hash, symmetry, interior zeros, prerelease, calendar, Unicode, large integers, unknown values | Provider-specific real app fixtures |
| A05/A10 remote parsing | Malformed plist, invalid cask neighbours, empty minimum OS | Live upstream changes |
| A06 instance identity | Canonical registration, unowned same-name app rejection, uncached Info.plist reads | Duplicate App Store installation on real volume |
| A07 reply lifecycle | Concurrent completion races, reply before waiter, late terminal events | Native XPC disconnect/timeout |
| A08 cancellation | Reaped process groups, owned preflight cancellation, safe installer handoff | Controlled real package cancellation |
| A09 progress | Monotonic phases and terminal-state protection; main-actor adapter build | Native Sparkle lifecycle |
| A11 Homebrew | Real v2 JSON schema, registered symlink and targeted fake-process upgrade | Controlled real cask update |
| A12 network/cache | HTTP rejection, status, body bound, downgrade rejection, malformed body and stale good cache | Native TLS/server behaviour |
| A13 inventory | Missing/disabled folders, current metadata, superseded generations | External volume/device events |
| A14 UI | Search, selection, notes, ignore persistence, German labels and screenshot XCUITests | VoiceOver, keyboard and large-text interaction |
| A15 release trust | Foreign signer rejection, requirement injection, Ed25519 valid/tampered signatures, signed feed envelope | Developer ID/notarization/self-update |
| A16 modern checks | Xcode 27 workflow, source/resource validation, native test scheme | Current final-head CI |
| Filtering / ignored / skipped / channels | Production resolution and presentation tests | UI interactions |
| Migration / persistence | One-time legacy migration, save/reload, missing new fields | Restart of normal signed app |
| Architecture | Mach-O headers and explicit incompatible feed/archive URLs | Actual installed executable after update |
| Release notes | Removed active markup, plain text, bounded response | Large text, accessibility and resizing |

Test counts and final-head results are recorded in acceptance.md. A source
contract test is not a substitute for any native acceptance cell above.
