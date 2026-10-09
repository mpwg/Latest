# Acceptance matrix

Baseline: beta 4c1e111, macOS 27.0.1, Swift 6.4 Command Line Tools.
Statuses: passed, open, not verifiable. Evidence must match current code.

| Criterion | Status | Evidence / next check |
|---|---|---|
| Audit and concept in own fork | passed | audit-2026-10-09.md, modernization.md |
| Swift 6 core and comparison contracts | open | Core and A04 regression tests |
| Canonical instances / scan generations | open | Duplicate and late-result tests |
| HTTPS / status / bounds / cache | open | Network/cache tests |
| Homebrew ownership / targeted updates | open | JSON fixtures / controlled integration |
| Bundled mas / restricted broker | open | Packaging / signatures / negative request tests |
| Sparkle 2.10.0 / lifecycle | open | Build / controlled signed appcast |
| SwiftUI / filtering / ignore / channels / migration | open | UI/migration checks |
| English/German string catalogues | open | Key/placeholder checks |
| Shared schemes / GitHub Actions | open | Xcode 27 build and tests |
| Native installation / receipts / architecture | not verifiable | Xcode / controlled signed test apps |
| Keyboard / VoiceOver / large text | not verifiable | Native interaction |
| Release signing / notarization / self-update | not verifiable | Own Developer ID / notarization / feed |
| README reflects current implementation | open | Update after implementation |

Overall acceptance: open.
