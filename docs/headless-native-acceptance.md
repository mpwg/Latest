# Native Sparkle through the shared core

Checked again on 2026-10-11 at `d6505ff`, macOS 27.0.1, Xcode 27.0 / Swift 6.4,
arm64. Actual fixture applications are Apple Development signed by team
`PZV43D6HWT`; an independent test-only Ed25519 key signs the localhost appcast
and archive. This is not Developer ID, notarization, Store or production
self-update acceptance.

The test uses `ApplicationSession` and `LiveApplicationRuntime`, including the
production inventory, signature/fingerprint preflight, Sparkle 2.10 user driver,
installation and installed-result verification. Swift Testing drives these APIs
directly. No Latest window, synthetic inventory, XCUITest, mouse click or
keyboard automation is involved. Real Sparkle installation helpers still run.

| Case | Observed result |
|---|---|
| valid | Selected signed app changes from 1.0.0 (1) to 1.1.0 (2); exactly one succeeded event |
| tampered | Modified real archive fails; selected 1.0.0 bundle bytes stay identical; exactly one failed event |
| signature | Invalid enclosure signature fails; selected 1.0.0 bundle bytes stay identical; exactly one failed event |
| retry | After signature rejection, restored valid feed/archive updates the same selected bundle without resetting it; exactly one succeeded event |

After **each** case, a separate new Swift test process creates a fresh native
runtime/session, loads the persisted preferences and reads the real installed
bundle/provider state. It observes `current` at 1.1.0 after success and
`available` at 1.0.0 after rejection, with no active installation job. This is a
process restart, not a replacement model inside the original process.

Independent checks verify deep/strict code signatures and the actual arm64
Mach-O executable. The other same-ID Sparkle instance, managed and unmanaged
Homebrew controls retain identical file hashes. The ordinary Homebrew Ruby
runtime also retains identical hashes. The isolated Homebrew vendor directory
now owns its copied runtime: automatic Ruby provisioning cannot follow a vendor
symlink into the ordinary installation.

## Reproduce and retained evidence

Use the prepared [disposable environment](native-fixtures.md). Reuse its approved
localhost certificate until expiry and start `native_fixtures.py serve` if needed.
First compile the opt-in test without enabling installation:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_sparkle.py all
```

The driver enables only `realSparkleRuntimeWithoutGUIAutomation`, requires the
known prepared root and live trusted localhost feed, and manipulates only the
fixture archive/feed/apps. `retry` requires the rejected baseline left by the
previous case. Default/CI tests skip this native test when its explicit opt-in
is absent. A skip never counts as native acceptance.

Retained private evidence is in
`.build/native-install-tests/evidence/headless-sparkle/{valid,tampered,signature,retry}/`:
`test.log`, `restart.log`, and `result.json` for every case. The JSON includes
revision, all relevant application/core/adapter/test-driver source hashes,
macOS/Xcode/architecture, exact arguments/path, actual accepted job events,
installed version, signature result and unchanged-control checks. Final source
maps are checked against the checkout; no private signing key is included.

The current certificate is unchanged and remains trusted for localhost in the
user domain. It expires on 2026-10-17 at 08:45:50 Vienna time. Native SSL trust
validation succeeds now and rejects a verification date one second after expiry.
Repeated `trust-localhost` merely verifies and reuses existing valid trust.

## Acceptance scope

| Criterion | Status | Evidence |
|---|---|---|
| Actual selected signed installation without GUI automation | passed | valid case; installed bundle, job journal, native provider/current state |
| Actual archive and signature rejection without target mutation | passed | tampered/signature cases, complete selected/control file hashes |
| Recovery without resetting rejected target | passed | retry case follows signature failure with the original 1.0.0 bundle |
| Genuine process restart after all outcomes | passed | Four separately spawned restart processes and retained restart.log |
| Identity/signature/architecture and unchanged other instances | passed | Production preflight/result checks, independent codesign/lipo/digests |
| Current documentation | passed | README, shared-core documentation and acceptance matrix |

Download cancellation, failure at HTTP transport, installer handoff, compatibility,
Homebrew and Store retain their separate native scopes. Earlier XCUITest evidence
is historical after the application extraction; those scenarios must be adapted
and rerun through the headless runtime. Manual accessibility/layout/language
acceptance also remains separate. No release was published.
