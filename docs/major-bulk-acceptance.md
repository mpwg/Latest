# Native major consent and bulk updates — L17 (#22)

Observed on 2026-10-10 at `11d08a6`, macOS 27.0.1 (26A434), Xcode 27.0
(27A266a), Swift 6.4, arm64. The client, runner and test bundles use the own
Apple Development team `PZV43D6HWT`. All installations use actual signed
archives, HTTPS, native controls and the production Sparkle adapter.

## Reproduce

Prepare [native fixtures](native-fixtures.md), their HTTPS server and the
approved temporary localhost trust, then run:

```sh
python3 scripts/native_major_bulk.py all
```

The four cases are `major`, `provider-major`, `changed-major` and `bulk`.
The driver creates a second loopback HTTPS server on an ephemeral port, restores
the original feed in `finally`, closes its server and retires generated bulk
apps outside the inventory. No ordinary user application is targeted.

## Criteria matrix

| Criterion | Status | Actual observed native result |
|---|---|---|
| Semantic major upgrade requires explicit consent | passed | Native Cancel leaves exact selected 1.0.0 bytes unchanged and starts no job; subsequent explicit consent installs signed 2.0.0 (2) |
| Provider-declared major requires consent | passed | Sparkle minimumAutoupdateVersion 2 marks target 1.1.0 (2) as major despite unchanged display major; Cancel/no-job and explicit consent are independently verified |
| Changed major requirement fails closed | passed | Start with a minor offer, add the signed provider-major requirement before Update; actual recheck rejects it, starts no archive download, ends once in failed and preserves all selected bytes |
| Bulk includes only authorized available minor targets | passed | Real original and distinct-ID minor app install signed 1.1.0 (2); semantic major, provider-declared major, ignored, skipped, incompatible, current and unknown bundles stay byte-for-byte unchanged |
| Update actions are disabled during an incomplete scan | passed | Actual HTTPS appcast request is gated while valid minor offers exist; selected/bulk actions are disabled, no job starts; releasing the real provider response completes the scan |
| Repeated activation creates no duplicate job | passed | Native double activation of Update All creates exactly one job per each of the two eligible canonical paths; bulk is disabled while real downloads are gated; each authorized job succeeds once |
| Identity, signatures, architecture and controls | passed | Native canonical-path selection plus independent Info.plist, deep/strict codesign and lipo checks; two actual arm64 targets, exact versions/builds, unchanged secondary instance/Homebrew and excluded apps |
| Current evidence and README | passed | README links reproduction; result.json records revision, environment, hashes, checkpoints, jobs, downloads, selected target metadata and unchanged-control result; unique xcresults and actual window screenshots retained |

Evidence is retained under `.build/native-install-tests/evidence/l17/{case}/`:
native log, unique `native-tests-*.xcresult` and `result.json`. The bulk case
retains a path manifest and moves its generated installed bundles to the
corresponding prepared evidence directory after verification.

Implementation changes: provider-declared major information is preserved in
the core candidate and revalidated before installation; UI and model reject
scan-time starts and repeated bulk activation. Active job count derives from
owned tasks even when inventory rows change. This supports quit protection;
its dedicated native acceptance remains L24.

The actual native hierarchy also exposed a macOS selectable-text wrapper
retaining the pre-update version while its child and pixels already showed
the installed version. Binding the version's accessibility value explicitly
fixes the observed stale value; the native check now verifies 2.0.0 at both
rendered and accessibility levels. This is not full VoiceOver acceptance.

Supporting current checks: warnings-as-errors Release build, 84 compiled
invariants, eleven Swift Testing contracts, seven appcast regressions and 74
English/German keys. Positive installation evidence here is scoped to Sparkle
on arm64. Store, legacy migration, accessibility and production release retain
their separate open criteria.
