# Acceptance matrix

Baseline: beta 4c1e111; local platform macOS 27.0.1 / Swift 6.4 Command Line Tools.
Verified implementation: modernization PR stack in mpwg/Latest, commit
`273136101412f767c02d40291bc08a456c2200b8`.
CI evidence: macOS 27, Xcode 27.0, Swift 6.4, runs completed on 2026-10-09
and logs/artifacts checked again on 2026-10-10.
Statuses: passed, open, not verifiable. Evidence must match current code.

| Criterion | Status | Evidence / next check |
|---|---|---|
| Audit and concept in own fork | passed | audit-2026-10-09.md, modernization.md |
| Swift 6 core and comparison contracts | passed | Compiled invariant suite, including symmetric source policies and hash/equality |
| Canonical instances / scan generations | passed | Current metadata, registered/unowned apps, removed/late results |
| HTTPS / status / bounds / cache | passed | Production client with deterministic URLProtocol transport fixtures |
| Homebrew ownership / targeted updates | passed | L03 targeted real native update and L04 native provenance-loss, changed-instance, informational catalogue and real failure/retry checks passed; scoped to isolated arm64/Tier 3 prefix |
| Bundled mas / restricted broker | open | Compiled/pinned tools, own/foreign signer checks, request and package policy passed; native privileged request/install outstanding |
| Sparkle 2.10.0 / lifecycle | open | Pinned distribution and main-actor adapter build passed; controlled signed appcast install outstanding |
| SwiftUI / filtering / ignore / channels / migration | open | Five native XCUITests passed on 2731361: search, selection/notes, ignore/restart, German labels, identifiers/screenshot. Source filters, sorting, channels, skip/major/bulk actions and normal signed-app migration remain open |
| English/German string catalogues | passed | 74 keys, translated states and placeholder parity |
| Shared schemes / GitHub Actions | passed | Both linked runs on 2731361 passed bootstrap, app build, 83 compiled invariants, validation, seven Swift Testing tests, five native UI tests and debug packaging |
| Native installation / receipts / architecture | not verifiable | Xcode / controlled signed test apps |
| Keyboard / VoiceOver / large text | not verifiable | Native interaction |
| Release signing / notarization / self-update | not verifiable | Own Developer ID / notarization / feed |
| Appcast history and complete-feed signatures | passed | L28 seven regressions on 3ba5c3d: preserved history/notes, ordering, first/empty feed, invalid/duplicate metadata and actual complete-feed signing/tamper rejection |
| README reflects current implementation | passed | Own fork, build/verification commands, features, restrictions and release status |

Overall acceptance: open.

## Subsequent native implementation evidence

L28 at `3ba5c3d` passes seven Python regressions including actual Swift Ed25519
signing/verification, seven Swift Testing contracts, 84 compiled invariants and
the warnings-as-errors build. [Release instructions](releasing.md) document
mandatory explicit history selection and authenticated merging. This does not
establish notarization, self-update or publication acceptance; the owner deferred
release credentials on 2026-10-10.

[L04](homebrew-native-rejection.md) adds four real native rejection/recovery
checks on `eec132b`, with no upgrade process for rejected provenance/instance/
catalogue requests and a real failed checksum upgrade followed by successful
rescan/retry. It preserves controls and records per-source hashes and xcresult
paths. Other provider, accessibility and production release gates remain open.

[L03](homebrew-native-acceptance.md) verifies `9cbec3d` on macOS 27.0.1 with
local Xcode 27.0 / Swift 6.4: one actual Homebrew-update XCUITest passed, seven
Swift tests and 84 compiled invariants passed. Real window screenshots and
observed targeted brew arguments match the installed bundle before/after.
The new optional installation test does not run against synthetic `--ui-testing`
inventory. The earlier CI section below remains explicitly scoped to 2731361;
the integrated L01/L02 main commit `a1903b8` also passed
[run 38032841390](https://github.com/mpwg/Latest/actions/runs/38032841390).

## Current CI evidence for 2731361

Both successful runs tested the exact implementation commit above:

| Run | Trigger | Retained artifact |
|---|---|---|
| [37988080394](https://github.com/mpwg/Latest/actions/runs/37988080394) | Pull request | [macOS-27-evidence / 11644028271](https://github.com/mpwg/Latest/actions/runs/37988080394/artifacts/11644028271) |
| [37988071896](https://github.com/mpwg/Latest/actions/runs/37988071896) | Push | [macOS-27-evidence / 11643464628](https://github.com/mpwg/Latest/actions/runs/37988071896/artifacts/11643464628) |

The downloaded artifacts each contain `native-tests.xcresult` and the controlled
debug `Latest.app`. The logs report **83 compiled production-code invariants**,
**74 English/German keys**, **seven Swift Testing tests** and **five native
XCUITests with zero failures**. Swift Testing runs both directly and in the
shared Xcode scheme; these are repeated runs of the same seven tests.
The UI suite runs real macOS views with `--ui-testing` and an isolated debug
inventory. Its exact behaviours and remaining limits are listed in
[test coverage](test-coverage.md#native-ui-evidence-for-2731361).

CI packages an **ad-hoc debug bundle**. It does not prove production signing,
privileged broker registration or any real provider installation.

## Earlier local evidence and its limits

The following observations were recorded during the modernization and are
retained as historical local evidence, not fresh production acceptance:

- `swift build -Xswiftc -warnings-as-errors`: passed locally. CLT linker reports
  missing optional Developer framework search directories; no Swift warning or
  source error was suppressed.
- `LATEST_TEST_APP_BUNDLE=<own Developer-signed fixture> .build/debug/LatestVerification`:
  **86 passed**: 83 core/process/adapter/transport checks plus three own signature
  and sealed tool-digest checks.
- `python3 scripts/validate.py`: **74 English/German keys passed**, source boundary,
  project plist and shared scheme syntax passed.
- `package_app.py`: own Developer-signed bundle, hardened runtime, matching actual
  TeamIdentifier, deep/strict code-signature verification passed. No service was
  registered and no installed application was changed.
- Controlled native launch: one own-fork process and a **1000 × 702** main window
  observed through CoreGraphics; isolated `.build/ui-smoke/preferences.json`.
  This proves startup, not VoiceOver or full interaction.

## L01 documentation acceptance (#6)

| Criterion | Status | Evidence |
|---|---|---|
| Exact implementation commit, both successful runs and xcresult links | passed | Commit and artifact table above; both artifacts downloaded and their result bundles checked on 2026-10-10 |
| Five native UI behaviours listed with separate remaining gates | passed | Native UI table in test-coverage.md; installation and accessibility rows remain open/not verifiable |
| Obsolete pending-CI claims removed; README remains consistent | passed | Shared-scheme row above and updated README release status |
| Evidence has environment, revision and observed result | passed | CI logs, artifact metadata and local documentation checks; no runtime code changed in L01 |

Developer ID/notarization and a real signed self-update remain unavailable in
this environment. Real App Store receipts/package compatibility and controlled
Sparkle/Homebrew updates are not inferred from fixture successes.
