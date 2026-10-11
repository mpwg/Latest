# Native directories, volumes and scan ownership through the shared core

Observed again on 2026-10-11 at `ead2e13`, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Four actual cases use ApplicationSession,
LiveApplicationRuntime, real signed bundles, uniquely owned HFS+ disk images
and controlled HTTPS. Each also passes in a separate restart process.

## Reproduce

With the prepared [native fixtures](native-fixtures.md), retaining the approved
localhost certificate/trust:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_directories.py all
```

The headless runner shares fixture preparation and independent verification with
the historical L19 driver, using separate preferences/evidence paths and direct
core commands. Explicit file checkpoints coordinate actual mount/ejection and
HTTP events. It restores no host preferences, installs no app, changes no TLS
certificate/trust and detaches only the uniquely owned test volumes in cleanup.

| Criterion | Status | Actual observed result |
|---|---|---|
| Directory disable/add/remove | passed | Exact discovered paths match the private initial folder; disabling empties inventory; adding the second folder twice yields one entry; removing initial leaves only the added app |
| Standard-directory exclusion and restart | passed | /Applications and user Applications remain disabled; real JSON retains only the added enabled folder and disabled standard entries; a fresh process verifies identical discovery/settings |
| Populated volume recovery | passed | Actual hdiutil detach causes the production five-second monitor to remove its app/selection and expose the exact unreadable-directory warning; actual remount clears the warning and restores discovery automatically |
| Empty volume recovery | passed | Actual ejection changes the warning despite unchanged empty app fingerprints; automatic monitoring detects both loss and remount recovery |
| Superseded real provider request | passed | Signed HTTPS response is held during the old scan; volume is ejected and directory removed; newer scan finishes empty; response is released and the captured obsolete scan task is awaited; no row/candidate/selection returns |
| Remount and fresh process after supersession | passed | Remount plus a new scan still respects the empty directory preference; another process remains empty without warnings or jobs |
| Controlled bundles and host runtime | passed | All scanned bundles, four unrelated provider fixtures and ordinary Homebrew Ruby runtime retain identical bytes; no installation journal entry is written |
| Cleanup and retained proof | passed | Every owned volume is detached after acceptance; private disk images, commands/PIDs, checkpoints, transport outcome, source hashes and real restart logs are retained |

Evidence: `.build/native-install-tests/evidence/headless-directories/{case}/`
contains `test.log`, `restart.log`, `result.json`; signed fixtures/images remain
in the sibling `prepared/` directory. JSON records revision, environment,
canonical paths, mounted state and the actual old HTTPS transport outcome.
The cancellation path can close the transport before its delayed bytes are
written; that observed outcome is recorded. Deterministic core tests separately
check late-result rejection. The native test waits for the captured old task's
completion after releasing the real response.

No GUI automation participates. Native folder-picker interaction, keyboard,
VoiceOver, layout/language presentation and production release remain separate
manual acceptance scopes. These tests prove the shared commands and native
filesystem/monitoring/provider behavior on the arm64 host.
