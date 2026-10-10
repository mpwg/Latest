# Native Homebrew acceptance — L03 (#8)

Verified implementation: `9cbec3d`, 2026-10-10, macOS 27.0.1, Xcode 27.0
(27A266a), Swift 6.4, arm64. The client and native XCTest runner use the own
Apple Development identity with actual team `PZV43D6HWT` and hardened runtime.

## Reproduce

Prepare the [disposable native fixtures](native-fixtures.md), start their HTTPS
server and configure the explicitly approved localhost trust. Then run:

```sh
python3 scripts/native_homebrew_acceptance.py
```

The script requires the managed baseline at 1.0.0. To reset only that disposable
cask after a completed run:

```sh
python3 scripts/native_fixtures.py set-cask-version 1.0.0
env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 \
  XDG_CONFIG_HOME="$PWD/.build/native-install-tests/user-config" \
  .build/native-install-tests/homebrew/bin/brew reinstall --cask --no-ask \
  --appdir="$PWD/.build/native-install-tests/applications" latest-native-fixture
python3 scripts/native_homebrew_acceptance.py
```

The driver makes version 1.1.0 available in the isolated tap, seeds separate
preferences and explicitly opts into `testNativeHomebrewUpdate`. That test is
skipped in ordinary CI without the fixture environment. It launches the actual
Latest app without `--ui-testing`, selects the real registered app, checks its
canonical path, clicks the real update button and waits for version 1.1.0 and
the verified `Up to Date` state. Native screenshots capture only Latest's window.

Generated evidence remains under `.build/native-install-tests/evidence/l03/`:
`result.json`, the Xcode log and a unique `native-tests-*.xcresult` containing
before/after screenshots. The result records the tested source revision,
AppModel/test-source hashes and the observed real upgrade processes. Full
desktop captures from earlier attempts are not delivery artifacts.

## Findings corrected within L03

1. A named `brew outdated --cask --json=v2 <token>` exits **1** when that cask is
   outdated. Previously Latest rejected this successful check. Exit 1 is now
   accepted only with valid JSON identifying exactly the selected token; exit 1
   without that token is rejected by an explicit regression.
2. Homebrew 7 uses the user's XDG configuration directory for custom-tap trust.
   The child environment previously dropped that location, so a trusted tap
   appeared untrusted. Keep only an absolute configured `XDG_CONFIG_HOME`;
   preserve the user's existing trust decision rather than trusting taps in
   production. Fixture trust/configuration is isolated under the generated root.

Both corrections use the real brew behaviour, not a changed fake-process
contract. Root broker environments remain separately constructed and unchanged.

## Criteria matrix

| Criterion | Status | Concrete evidence |
|---|---|---|
| Exactly the selected, locally registered cask updates | passed | Real Caskroom registration; observed `brew upgrade --cask --no-ask latest-native-fixture` via both brew.sh and portable Ruby |
| Installed bundle is re-read before success | passed | Production AppModel checks bundle ID, target version and architecture, then rescans; native UI shows `1.1.0 (2)` / `Up to Date` with update disabled |
| Other apps/casks remain unchanged | passed | Byte digests of the equal-name unmanaged 1.0.0 copy and Sparkle fixture unchanged; host cask registry identical; update runs exclusively in the separate prefix |
| Current code, environment and before/after proof | passed | Native XCUITest: one test, zero failures, 10.986 seconds; result bundle `native-tests-d1007bf9b79d44ebb3bf2f23fc19b93c.xcresult`; both window screenshots inspected |
| Regression and README coverage | passed | 84 compiled invariants, seven Swift Testing tests, 74 localization keys and diff validation passed; README and fixture instructions updated |

The actual UI test reads the expected selected app path before installing, so
the equal-name unmanaged instance is not selected accidentally. Xcode's test
runner needed the owner's macOS approval when changing from ad-hoc to own
Development signing; that approval was given before the successful runs.

## Limits

This is a real Homebrew 7 cask update in a **nonstandard, isolated Tier 3 prefix**
with own signed local archives on one arm64 Mac. It does not prove other
architectures, arbitrary upstream casks, App Store installation or Sparkle
installation. L04 still owns provenance-loss, changed-instance and failed-update
native checks; overall production acceptance remains open.
