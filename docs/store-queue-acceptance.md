# Serialized Store workflows in the shared application core

Checked at `ead2e13`, 2026-10-11, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. The broker intentionally accepts one active update; concurrent
Store jobs from bulk previously reached its busy rejection. ApplicationSession
now owns a cancellable queue for Store workflows, shared by GUI and future CLI.
Other providers retain independent execution.

The permit spans selected-instance validation, a fresh check for queued offers,
installation and installed-result verification. Every exit releases ownership.
Waiting jobs remain queued/cancellable and count toward quit protection. Queued
requests cancelled before ownership do not validate or invoke installation.
After waiting, a changed/ignored/skipped/incompatible/nonauthoritative offer
cannot reuse the previous authorization. Version, action, fingerprint, major
requirement and channel remain bound to the requested candidate.

## Reproduce

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
```

Six StoreWorkflowTests drive the production ApplicationSession with an injected
exclusive Store capability and explicit continuation gates. There is no GUI
automation, fixed observation delay, real Store account or installer invocation.
These tests prove queue policy and workflow ownership; they do not prove actual
Store installation.

| Criterion | Status | Current observed result |
|---|---|---|
| Exclusive Store bulk plus other-provider progress | passed | Two Store jobs never overlap; Sparkle progresses while the first Store job is held; repeated bulk activation creates no duplicates |
| Ownership through verification | passed | Second Store job remains queued even after first installation finishes while verification is held; after release all three jobs finish once |
| Registered waiter cancellation and retry | passed | Test observes one actual queued continuation, cancels twice, sees cancellation finish while the first job is still held; no validation/install for cancelled target; requeued retry succeeds |
| Installation failure releases next job | passed | Failed first Store job releases second, which succeeds; first retry then succeeds without overlapping ownership |
| Fresh queued offer and ignore rejection | passed | Changed major/version offer and separately ignored queued target fail before the installer; first authorized target still succeeds |
| Verification failure releases ownership | passed | Failed first verification leaves a failed event and lets the next queued job complete; no owner/waiter remains |
| Build and default tests | passed | Warnings-as-errors Debug/Release, 84 invariants, 14 Python tests and 74 localized keys; 31 deterministic Swift functions plus nine separately skipped native opt-ins |
| Native Xcode target | passed | Xcode MCP builds test targets and runs 31 selected functions with zero failures/skips, including all six Store workflow tests |
| Actual privileged Store bulk | not verifiable | Requires SMAppService system approval and controlled authentic receipt/account/update; those prerequisites remain unavailable |

Private evidence includes `.build/store-queue-tests.log`,
`.build/store-queue-xcode-evidence.json` and its native xcresult. The current
37 native scenarios are also rerun after this application change; their source
maps, logs and exact scopes are retained separately. No release is published
and the existing certificate/trust is unchanged.
