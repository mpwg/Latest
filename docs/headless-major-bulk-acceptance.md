# Native major consent and scoped bulk installation through the shared core

Observed again on 2026-10-11 at `ead2e13`, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Four actual native cases drive ApplicationSession and
LiveApplicationRuntime with real signed apps, signed appcasts/archives and
controlled HTTPS requests. There is no GUI automation, injected inventory,
provider result or installer. Each case also passes in a fresh restart process.

## Reproduce

Prepare [native fixtures](native-fixtures.md), retain the approved localhost
certificate/trust and run their HTTPS server. Then:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_major_bulk.py all
```

The existing fixture preparation and independent bundle/job verification are
shared with the historical L17 driver. The headless runner replaces its GUI
execution with direct Swift tests and has its own preferences/evidence paths.
It starts an additional localhost HTTPS server using the existing certificate,
restores the original feed and retires generated bulk apps afterwards. It never
creates, rotates or changes trust for a certificate.

Explicit file checkpoints expose reached session states to the driver. This is
required because Swift Testing buffers test stdout until completion. The driver
checks actual bundle bytes and journals before releasing real provider/download
gates; it does not replace application state or installation outcomes.

| Criterion | Status | Actual observed result |
|---|---|---|
| Semantic major consent/cancellation | passed | Real 2.0.0 offer requires pending consent; bulk and cancelled/empty confirmation start no job; later explicit consent installs signed 2.0.0 (2) exactly once |
| Provider-declared major consent | passed | Signed minimumAutoupdateVersion 2 marks real 1.1.0 (2) as major; same cancellation/no-job and explicit-consent proof, one successful installation |
| Changed requirement rejected | passed | Real signed feed changes after the minor offer; install-time recheck rejects changed major policy, one failed job, zero archive requests, unchanged selected bundle |
| Scan-time commands rejected | passed | Actual HTTPS scan request is held while a minor candidate already exists; selected and bulk commands start no jobs; releasing the actual response completes the scan |
| Scoped bulk and duplicate rejection | passed | Two eligible canonical paths each download once and install signed 1.1.0 (2); repeated bulk/selected commands create exactly two jobs, each succeeds once |
| Active job protection | passed | Two real held downloads expose two owned jobs, disabled selected/bulk eligibility and quit protection; release leads to real verification/completion |
| Excluded bundles unchanged | passed | Semantic/provider-major, ignored, skipped, incompatible, current and unknown apps preserve exact bytes and start no jobs; secondary same-ID and managed/unmanaged Homebrew controls are also unchanged |
| Identity, signature and architecture | passed | Independent Info.plist, deep/strict codesign and arm64 lipo checks on actual installed targets; exact paths and terminal journals match the authorized set |
| Four fresh process restarts | passed | Major/minor installed versions remain current; rejected changed-major target stays 1.0.0 with a major offer; excluded bulk states remain correct and no new job starts |

Private evidence lives under
`.build/native-install-tests/evidence/headless-major-bulk/{case}/`:
`test.log`, `restart.log`, `paths.json` and `result.json`. JSON contains revision,
all relevant core/application/platform source hashes, environment, process
commands/PIDs, exact canonical paths, checkpoints, request counts, installed
versions/architectures and per-job outcomes. Prepared targets and retired bulk
bundles remain in the sibling `prepared/` directory. The ordinary Homebrew Ruby
runtime remains unchanged.

Default Swift runs execute 31 deterministic functions and skip nine native
opt-ins; skips are not installation proof. Xcode MCP discovers the additional
opt-in and runs 24 selected deterministic functions with zero failures/skips.
These native cases replace historical L17 GUI automation for correctness. Manual
dialog/keyboard/VoiceOver/layout acceptance, volumes, Store/broker and production
release signing/notarization/self-update remain separate open criteria.
