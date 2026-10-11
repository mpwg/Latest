# Native Homebrew through the shared application core

Checked revision: `1dd0240`, 2026-10-11, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Five actual cases pass through ApplicationSession and
LiveApplicationRuntime without a Latest window, XCUITest or GUI automation.
The real brew operates only in the prepared nonstandard **Tier 3** prefix.
Actual controlled apps are Apple Development signed by team PZV43D6HWT.

| Case | Actual observed outcome |
|---|---|
| valid | Real targeted upgrade changes the managed 1.0.0 app to verified 1.1.0; one real upgrade process and one succeeded terminal event |
| loss | The same app bundle/inodes are parked while real brew unregisters it, then restored; its fingerprint and bytes remain identical. Fresh ownership validation rejects the stale request; zero upgrade processes; one failed event; rescan reports unknown |
| swap | A different valid signed 1.1.0 app replaces the selected 1.0.0 bundle before the request. Instance preflight rejects it; zero upgrade processes and one failed event; replacement bytes remain identical |
| catalogue | Real localhost HTTPS metadata offers 2.0.0 for an unmanaged same-name/same-ID instance. Its candidate stays nonauthoritative/unknown, cannot update, starts no job and invokes no upgrade |
| retry | An intentionally wrong real cask checksum makes the first actual upgrade fail before changing the 1.0.0 bundle. Restoring the valid checksum, rescan and a new request install verified 1.1.0. Two distinct real upgrade processes produce failed then succeeded, exactly once per job |

Each case then spawns a **new process** with a fresh native runtime, reloads its
persisted preferences and checks actual disk/provider state. It starts no job.
The swap restart truthfully retains Homebrew's outdated registration state even
though the externally replaced executable is already 1.1.0; this does not turn
the rejected old request into an installation. The catalogue restart checks the
exact unmanaged instance.

Managed/unmanaged same-name instances and both Sparkle controls are independently
hashed. All unrelated instance bytes remain unchanged. Normal Homebrew cask
names and its ordinary Ruby-runtime bytes match before/after. Actual target
code signatures pass deep/strict verification; lipo reports arm64. No authentic
Store receipt is simulated or inferred from these fixtures.

## Process output correction

Homebrew can write diagnostics to stderr beside valid stdout JSON. Previously,
CommandRunner merged both streams, and Ruby provisioning warnings caused real
provider parsing to fail. It now owns separate nonblocking pipes, with one total
byte budget and the same cancellation/process-group/deadline protections.
JSON and prefix/payload parsing use stdout only; human failures include both
streams. A real Python subprocess emits warning text beside valid JSON, and a
second actual process exceeds the diagnostic limit and is rejected/reaped.
Current 84 process/core invariants remain green.

## Reproduce and retained evidence

Compile once, then run only against the prepared disposable environment:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_homebrew.py all
```

The controlled catalogue requires the existing fixture HTTPS server and approved
localhost trust; reuse the same certificate until natural expiry. No certificate
setup/rotation is performed by the driver. Default/CI runs skip the native test
without its explicit opt-in; skips never establish native acceptance.

Private evidence:
`.build/native-install-tests/evidence/headless-homebrew/{valid,loss,swap,catalogue,retry}/`.
Each contains test.log, restart.log and result.json with revision, hashes of all
shared core/native adapter/process/trust/contract sources, environment, exact
instance, actual process PID/argv, job phases, external checkpoints, observed
installed/provider state, signature/architecture and unchanged-control checks.
The file gates only coordinate real external fixture operations after the
production session reaches its checkpoint. No fake executable, registration,
receipt or installer outcome is substituted.

## Current acceptance

| Criterion | Status | Evidence |
|---|---|---|
| Exact managed target update and unchanged foreign instances | passed | valid case, independently verified installed metadata/signature/architecture and control digests |
| Loss of genuine ownership rejected despite unchanged selected identity | passed | loss case preserves fingerprint/bytes, removes actual registration and invokes zero upgrade processes |
| Changed selected signed instance rejected before provider mutation | passed | swap case and unchanged replacement/control digests |
| Catalogue/name metadata cannot authorize installation | passed | Real HTTPS hint on the unmanaged instance; no job or upgrade |
| Real error and successful retry; one terminal outcome per job | passed | Wrong-checksum failure, unchanged baseline, restored cask, distinct real processes and failed/succeeded journals |
| Actual process restart and persistence | passed | Five separately spawned restart processes with fresh native runtime |
| Current local checks and documentation | passed | 24 deterministic Swift functions, 84 invariants, 14 release regressions, 74 localized keys, warnings-as-errors builds; README and matrix |

This is native evidence for one own signed cask, one arm64 Mac and a Tier 3
prefix. Default prefixes/arbitrary casks, other architectures, Store/broker,
manual accessibility and production release gates retain their distinct scopes.
The separate four-case Sparkle suite passes again at this shared-adapter revision.
Overall release acceptance remains open; nothing was published.
