# Acceptance matrix

Baseline: beta 4c1e111, macOS 27.0.1, Swift 6.4 Command Line Tools.
Implementation: modernization PR stack in mpwg/Latest, through 6773493.
Statuses: passed, open, not verifiable. Evidence must match current code.

| Criterion | Status | Evidence / next check |
|---|---|---|
| Audit and concept in own fork | passed | audit-2026-10-09.md, modernization.md |
| Swift 6 core and comparison contracts | passed | Compiled invariant suite, including symmetric source policies and hash/equality |
| Canonical instances / scan generations | passed | Current metadata, registered/unowned apps, removed/late results |
| HTTPS / status / bounds / cache | passed | Production client with deterministic URLProtocol transport fixtures |
| Homebrew ownership / targeted updates | open | Local registered fixture and targeted process passed; real controlled cask update outstanding |
| Bundled mas / restricted broker | open | Compiled/pinned tools, own/foreign signer checks, request and package policy passed; native privileged request/install outstanding |
| Sparkle 2.10.0 / lifecycle | open | Pinned distribution and main-actor adapter build passed; controlled signed appcast install outstanding |
| SwiftUI / filtering / ignore / channels / migration | open | Core/persistence fixtures passed; visible Developer-signed native main window; final XCUITest outstanding |
| English/German string catalogues | passed | 74 keys, translated states and placeholder parity |
| Shared schemes / GitHub Actions | open | Xcode 27 builds and Swift Testing passed on 9ce86aa; UI compile warning corrected in 6773493; final run pending |
| Native installation / receipts / architecture | not verifiable | Xcode / controlled signed test apps |
| Keyboard / VoiceOver / large text | not verifiable | Native interaction |
| Release signing / notarization / self-update | not verifiable | Own Developer ID / notarization / feed |
| README reflects current implementation | passed | Own fork, build/verification commands, features, restrictions and release status |

Overall acceptance: open.

## Current concrete evidence

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
- [Xcode run 37985458283](https://github.com/mpwg/Latest/actions/runs/37985458283):
  dependency/bootstrap, app build, regression executable, repository validation
  and Swift Testing passed. Native UI build failed on a warnings-as-errors
  trailing-closure diagnostic; source was corrected without relaxing warnings.

Developer ID/notarization and a real signed self-update remain unavailable in
this environment. Real App Store receipts/package compatibility and controlled
Sparkle/Homebrew updates are not inferred from fixture successes.
