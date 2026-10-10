# Test coverage and evidence

`LatestVerification` executes production core/adapter code with controlled
fixtures on macOS 27. It performs no root installation and no user-app update.
`LatestCoreTests` provides the Xcode Swift Testing suite; `LatestUITests` uses
the real native SwiftUI views with an isolated debug fixture inventory.
The separate [native installation fixtures](native-fixtures.md) prepare signed
baseline/target bundles and an isolated real Homebrew cask. Their preparation
and HTTPS checks do not replace the remaining provider installation acceptance.

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
| A11 Homebrew | Real v2 schema and exit-1 regression; actual native update, provenance loss, changed-instance rejection, informational catalogue and real failure/retry; unchanged controls | Default-prefix, arbitrary-cask and other-architecture coverage |
| A12 network/cache | HTTP rejection, status, body bound, downgrade rejection, malformed body and stale good cache | Native TLS/server behaviour |
| A13 inventory | Missing/disabled folders, current metadata, superseded generations | External volume/device events |
| A14 UI | Five native XCUITests passed on 2731361; exact cases below | Source filtering/sorting, skip/channel/major/bulk interactions; VoiceOver, keyboard and large text |
| A15 release trust | Foreign signer rejection, requirement injection, Ed25519 valid/tampered signatures, signed feed envelope | Developer ID/notarization/self-update |
| A16 modern checks | Both Xcode 27 runs on 2731361 passed all workflow steps, seven Swift tests and five native UI tests | Re-run affected checks when implementation changes |
| Filtering / ignored / skipped / channels | Production resolution and presentation tests | UI interactions |
| Migration / persistence | One-time legacy migration, save/reload, missing new fields | Restart of normal signed app |
| Architecture | Mach-O headers and explicit incompatible feed/archive URLs | Actual installed executable after update |
| Release notes | Removed active markup, plain text, bounded response | Large text, accessibility and resizing |

Test counts and final-head results are recorded in acceptance.md. A source
contract test is not a substitute for any native acceptance cell above.

The additional opt-in `testNativeHomebrewUpdate` has passed locally under
Xcode 27 against the signed real fixtures. It is skipped when the explicit
fixture environment is absent; the five earlier UI tests retain their original
scope. [L03 evidence and criteria](homebrew-native-acceptance.md) describe the
real update, its retained xcresult and its isolated-prefix limits.
The four additional opt-in [L04 native cases](homebrew-native-rejection.md)
exercise the real installation boundary and error recovery. All five native
installation tests require explicit fixture setup; ordinary CI still checks the
five standard UI behaviours and skips those installation cases.

## Native UI evidence for 2731361

Verified implementation: `273136101412f767c02d40291bc08a456c2200b8`.
Both [PR run 37988080394](https://github.com/mpwg/Latest/actions/runs/37988080394)
and [push run 37988071896](https://github.com/mpwg/Latest/actions/runs/37988071896)
passed on macOS 27 with Xcode 27.0 / Swift 6.4. Logs and downloaded artifacts
were inspected on 2026-10-10. Their `native-tests.xcresult` bundles are in the
[PR artifact](https://github.com/mpwg/Latest/actions/runs/37988080394/artifacts/11644028271)
and [push artifact](https://github.com/mpwg/Latest/actions/runs/37988071896/artifacts/11643464628).

| Native test | Observed behaviour | Limit |
|---|---|---|
| testSelectionAndPlainReleaseNotes | Select the identified fixture row; plain fixture notes and update button appear | Does not activate an installer or fetch remote notes |
| testSearchFiltersAndRestoresInventory | An unmatched search hides the row; clearing it restores the row | Does not test source filters or sorting |
| testIgnoreIsPersistentAndHidesRow | Ignore the fixture, terminate and relaunch with the same isolated preferences; row remains hidden | Does not test normal signed-app startup or legacy migration |
| testGermanInterface | German launch shows the expected localized empty-selection label | Does not establish complete German interaction or VoiceOver |
| testAccessibilityIdentifiersAndScreenshot | Refresh button is found; native window screenshot is attached | Identifiers and screenshots do not prove screen-reader, keyboard or large-text acceptance |

The suite reports five tests and zero failures in each run. All use the real
native views with `--ui-testing`, one controlled debug inventory and isolated
preferences. The existing suite does not establish provider installation,
privileged XPC behaviour, source filtering/sorting, version skipping, channel
selection, major/bulk update actions or complete accessibility. Those remain
separate acceptance tasks in the [work overview](https://github.com/mpwg/Latest/issues/5).
