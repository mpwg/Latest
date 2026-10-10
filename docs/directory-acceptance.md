# L19 native directories, volume loss and superseded scans

All four native cases passed on 2026-10-10 at `53dc1df`, macOS 27.0.1 /
Xcode 27.0 / Swift 6.4, arm64. Client, runner
and actual disposable bundles use the own Apple Development team `PZV43D6HWT`.
No synthetic app records or provider results are supplied.

## Reproduce

Prepare [native fixtures](native-fixtures.md) and approved localhost TLS trust,
then run:

```sh
python3 scripts/native_directories.py all
```

The driver owns temporary signed bundles and uniquely named disk images/mounts.
The native client reads an isolated preferences directory and Homebrew prefix.
Standard `/Applications` and user Applications entries start disabled; their
exclusion is verified against the complete actual visible app-path list.
Folder addition uses the real NSOpenPanel, Command-Shift-G path entry and native
Return confirmation. No host application is updated or installation job started.

## Criteria matrix

| Criterion | Status | Actual observed result at 53dc1df |
|---|---|---|
| Disabled standard and selected directories exclude apps | passed | Exact visible path list contains only the controlled selected folder; native disable produces an empty list and persisted disabled entries |
| Native folder selection/add/remove and persistence | passed | Native panel adds the signed second app; native removal excludes the first; normal Command-Q/relaunch preserves the second folder and disabled standard entries |
| Ejected populated volume | passed | Actual image detach removes its app; automatic monitoring displays Cannot read directory with its exact path; remount clears the warning and restores the app without crash |
| Ejected empty volume | passed | Actual detach produces the warning despite unchanged empty app fingerprints; remount clears it automatically |
| Superseded provider result | passed | Real signed HTTPS appcast held during the old scan; volume ejected and its directory removed through Settings; newer scan finishes empty; delayed response released afterwards cannot restore the app or stale candidate over a seven-second observation |
| Unrelated instances unchanged | passed | Scanned signed bundles and ordinary fixture controls remain byte-for-byte unchanged; job journal stays empty |
| Evidence and README | passed | Reproduction, source hashes, actual native logs/xcresults, settings checkpoints, mounted-state checks and retained screenshots accompany this record |

The first native folder-removal run exposed a Swift exclusivity crash: its
`removeAll` predicate reread the live directory binding while mutating the
containing preferences. Removal now captures the path before mutation and lets
the existing settings observer save and refresh once. A later actual complete
folder sequence, including ordinary quit/restart, passed. The failure xcresult
`actions/native-tests-9bc8342c11a1473d941c01bc72ccc2a3.xcresult` remains retained.

Monitoring now compares inventory warnings as well as app fingerprints. Parent
scan cancellation reaches the detached inventory task. Generation/cancellation
ownership is rechecked after inventory/ledger suspension points before touching
rows, including after provider record acceptance. Cancellation and generation
checks jointly reject obsolete results; the controlled native HTTP flow does not
simulate an arbitrary callback after cancellation.

Evidence root: `.build/native-install-tests/evidence/l19/`.
`{actions,volume,empty-volume,stale}/result.json` retains exact revision/source
hashes, environment, paths, observed checkpoints, transport outcome and native
result-bundle path. `native-tests.log` and unique xcresults accompany each case.
The delayed signed HTTPS response was actually sent after the newer generation
removed its app; no stale row returned. Supporting checks pass: warnings-as-errors
Release build, 84 compiled invariants, 11 Swift Testing contracts, seven appcast
regressions and 74 English/German localization keys.

Disk images remain as reproducible private evidence; all owned volumes are
unmounted in driver cleanup. Screenshot attachments cover persisted settings
and actual volume-loss warnings.

This checks the English directory warning and actual local arm64 filesystem/
provider flows. VoiceOver, large text, full bilingual diagnostics and privileged
App Store/release acceptance remain separate requirements. It does not establish
that every possible filesystem race or production release criterion is complete.
