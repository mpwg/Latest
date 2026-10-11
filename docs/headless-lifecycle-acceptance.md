# Sparkle lifecycle through the shared application core

Checked at `7f43333`, 2026-10-11, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Three real native cases use ApplicationSession and
LiveApplicationRuntime with actual signed apps and Sparkle 2.10. No Latest GUI,
XCUITest or synthesized input is used. The existing approved localhost
certificate serves all controlled HTTPS endpoints unchanged.

| Case | Actual observed result |
|---|---|
| cancellation | Real HTTPS archive transfer starts and flushes initial data while the server holds the remainder. The core exposes cancellation; two cancel commands produce exactly one cancelled outcome and no error dialog state. Selected app bytes stay unchanged. A fresh check and valid retry install signed 1.1.0 with one succeeded outcome |
| download-error | Actual archive server returns HTTP 503. The job fails once, shows error state and leaves selected 1.0.0 bytes unchanged. Restored real feed/archive, rescan and retry install verified 1.1.0 with one succeeded outcome |
| handoff | The selected signed fixture is an actually running, natively registered process. Its canonical bundle identity is checked via NSRunningApplication, then it is stopped through its exact PID. Real extraction/installer handoff disables cancel/quit. A cancel command leaves the one active job running. Selected bytes stay unchanged while the fixture is stopped; resuming it lets real termination/replacement finish once at signed 1.1.0 |

The handoff scenario operates only on the disposable fixture PID/executable.
The fixture can create its own native window; no window interaction is performed.
OS process registration, signals and native installer execution constitute the
real app-termination boundary, rather than an injected installer result.

After each outcome, a separately spawned new process creates a fresh native
runtime/session and observes actual 1.1.0 / current with no active job. Independent
codesign deep/strict and lipo checks validate the installed signature and arm64
executable. Other same-ID and Homebrew control bytes remain identical. Each
actual job journal has exactly one terminal result: cancelled/succeeded,
failed/succeeded, or succeeded for handoff.

## Reproduce and retained evidence

Use the prepared signed fixture environment and its existing trusted certificate.
Start the standard localhost fixture feed server if necessary, then:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_lifecycle.py all
```

Default/CI runs skip this native opt-in. The independent application/adapter
contracts still execute normally; a skip is never native acceptance.

Retained private evidence:
`.build/native-install-tests/evidence/headless-lifecycle/{cancellation,download-error,handoff}/`.
Each has test.log, restart.log and result.json. The JSON records exact revision,
all core/application/native/process/trust/contract source hashes, environment,
actual transport status/byte gate, pre-recovery file checks, handoff PID and
cancellation state, accepted job phases, installed version/signature/architecture,
unchanged controls and new-process restart. File gates coordinate external
transport/fixture actions after the shared session observes the actual state.

The download may remain indeterminate after a small received packet. The test
therefore waits for the real HTTPS request/data flush plus the actual downloading
and cancellable state; it does not invent a percent value or assume immediate
progress callbacks.

## Current criteria

| Criterion | Status | Evidence |
|---|---|---|
| Real cancellable download and unchanged baseline | passed | cancellation case, actual gated transfer, terminal/canQuit/error state and byte check |
| Actual download error and bounded recovery | passed | HTTP 503, failed state, unchanged baseline and real successful retry |
| Safe installer handoff and honest cancellation/quit eligibility | passed | Registered actual PID, stopped process, installing state, rejected cancel and actual completed replacement |
| Exact instance, signatures, architecture and unaffected controls | passed | Actual disk/provider verification and independent signature/lipo/digests |
| Exactly one outcome per job and new-process restart | passed | Three journals and separate native restart processes |
| Current documentation and local checks | passed | README/matrix/test coverage, 24 deterministic Swift functions, 84 invariants, 14 release regressions and warnings-as-errors builds |

The five headless Homebrew and four signed Sparkle update/rejection/retry cases
also pass again at this same test-source revision. Store/broker, remaining
compatibility/volume scopes, manual accessibility and production release/self-
update remain distinct open criteria. No release was published.
