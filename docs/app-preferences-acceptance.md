# Native app preferences — L16 (#21)

Observed on 2026-10-10 at `2743f68`, macOS 27.0.1 (26A434), Xcode 27.0
(27A266a), Swift 6.4, arm64. Client, runner and bundles use the own Apple
Development team `PZV43D6HWT`. Both cases use actual signed app instances,
controlled signed HTTPS appcasts, the production Sparkle check adapter,
SwiftUI controls and the real preferences store. Inventory is read from disk.

## Reproduce

Prepare [native fixtures](native-fixtures.md), their HTTPS server and the
previously approved localhost trust, then run:

```sh
python3 scripts/native_app_preferences.py all
```

The driver restores two signed 1.0.0 instances and prepares a signed 1.2.0 (3)
target archive. For `ignore-skip`, it first serves stable 1.1.0 (2), then changes
the actual appcast to 1.2.0 only after XCTest completes the skip checkpoint.
For `channels`, the actual appcast contains stable 1.1.0 (2) and beta 1.2.0 (3).
The driver always restores the original feed. `showIgnored` is enabled in the
isolated preferences so native controls can reverse hidden-state decisions.

## Criteria matrix

| Criterion | Status | Actual observed native result |
|---|---|---|
| Ignore survives restart and can be reversed | passed | Native Ignore action disables Update; relaunch retains Stop Ignoring; reversing the action enables the verified update again |
| A skipped concrete version persists and can be cleared | passed | Native Skip marks 1.1.0 (2) as Version Skipped and disables Update; relaunch retains it; Clear Skipped Version enables Update again |
| Later versions are not suppressed by an earlier skip | passed | Skip 1.1.0 again, serve signed stable 1.2.0 (3), refresh and relaunch; the actual provider reports 1.2.0 (3) and Update is enabled |
| Skip affects only the selected canonical instance | passed | Selected top-level path remains skipped while the same-ID secondary path remains actionable |
| Stable/Beta is per instance and persists | passed | Native Beta selection switches top-level offer to 1.2.0 (3), retained after relaunch/refresh; secondary instance still offers stable 1.1.0 (2); return to Stable and relaunch retains 1.1.0 (2) |
| Saved state independently matches the observed UI | passed | Driver checkpoints exact selected skip ID and sole beta channel key in the real JSON file; final channel is Stable at only that canonical path |
| Bundles, evidence and README | passed | Selected/secondary Sparkle and Homebrew bundles all unchanged byte-for-byte; no installation job starts; README links reproduction; xcresults, hashes and environment retained |

Ignoring is bundle-ID scoped by product design; skipping and channels are
canonical-path scoped. The two actual XCUITests passed with zero failures.
Retained evidence: `.build/native-install-tests/evidence/l16/{case}/` contains
native logs, unique `native-tests-*.xcresult` and `result.json` with source
revision/hashes, environment, selected/other paths and checkpoint/final settings.

Supporting current checks: warnings-as-errors Release build, 84 compiled
invariants, ten Swift Testing contracts, seven appcast regressions and 74
English/German keys. These cases verify native preference behaviour with actual
provider checks; actual installation, major/bulk, legacy migration, accessibility
and production release retain their own criteria.
