# Native Sparkle installation — L05 (#10)

Observed on 2026-10-10 at implementation `f262a29`, macOS 27.0.1,
Xcode 27.0 / Swift 6.4, arm64, own Development-signed client and fixtures
(`PZV43D6HWT`). These are real Sparkle 2.10 installations through Latest's
native UI and production adapter, with a controlled localhost HTTPS appcast.

## Reproduce

Prepare the [disposable native fixtures](native-fixtures.md), start their HTTPS
server and use the previously approved temporary localhost trust. Then run:

```sh
python3 scripts/native_sparkle_acceptance.py all
```

Individual cases are `valid`, `tampered` and `signature`. Each restores two
signed 1.0.0 instances from the prepared baseline. Previous disposable bundles
are preserved under `evidence/l05/reset-backups/`. No production app is targeted.
The driver always restores the original archive and feed after each case.

## Criteria matrix

| Criterion | Status | Current native evidence |
|---|---|---|
| Valid signed update installs the target version | passed | Native Update action installs 1.1.0 (2); production post-install verification and subsequent scan display Up to Date; driver independently reads Info.plist and verifies deep/strict code signing |
| Exact selected canonical instance | passed | UI asserts the selected top-level path; second same-ID, same-name instance remains byte-for-byte unchanged at its separate path |
| Modified archive is rejected | passed | Append bytes without updating signature; actual UI reports Update Failed; selected bundle stays byte-for-byte at 1.0.0 |
| Invalid update signature is rejected | passed | Replace enclosure Ed25519 signature; actual UI reports Update Failed; selected bundle stays byte-for-byte at 1.0.0 |
| Controls, evidence and README | passed | Other Sparkle instance and Homebrew fixture bytes unchanged in all three cases; result.json records implementation revision, production/test source hashes and retained xcresult; README links this procedure |

Evidence lives under `.build/native-install-tests/evidence/l05/{case}/`.
Each directory retains `native-tests.log`, `result.json` and a unique
`native-tests-*.xcresult`. All three tests passed with zero failures on the
revision above. The positive case retains a screenshot of the actual window.
Supporting current checks passed: Release build with warnings as errors,
84 compiled invariants and validation of 74 English/German keys.

This evidence is limited to the disposable arm64 bundles and controlled feed.
Download cancellation, failed startup, late callbacks, compatibility boundaries,
privileged/App Store installation, accessibility, Developer ID, notarization and
Latest's own production self-update remain separate gates. Overall acceptance
remains open.
