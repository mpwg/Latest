# Native app-instance integrity — #51

Observed on 2026-10-10 at `dbd576e`, macOS 27.0.1 / Xcode 27.0 / Swift 6.4,
arm64. Client, runner and fixture apps use the own Apple Development team
`PZV43D6HWT`. These cases use actual selected bundles, native Update actions,
the production preflight and a real signed Sparkle installation.

## Reproduce

Prepare [native fixtures](native-fixtures.md), the HTTPS server and approved
localhost trust, then run:

```sh
python3 scripts/native_instance_integrity.py all
```

`replacement` compiles another real optimized fixture executable, replaces the
selected executable and signs the bundle again. `tampered` changes one byte
and independently confirms an invalid signature. Both preserve Info.plist bytes
and restore Info.plist/executable modification times before native Update.
The controlled scan hold prevents a rescan from masking the stale candidate;
it does not replace inventory/provider results. `valid` performs the actual
signed selected-instance installation.

## Criteria matrix

| Criterion | Status | Actual observed native result |
|---|---|---|
| Actual instance identity is compared | passed | Fingerprint binds bundle/executable filesystem identity, architecture, code-directory digest/team and bounded receipt contents alongside metadata |
| Signed executable replacement with unchanged metadata is rejected | passed | Own valid signed replacement and identical Info.plist/times; actual Update fails once before checking/downloading/installer dispatch |
| Signature tampering with restored times is rejected | passed | Independent codesign confirms invalid signature; native preflight rejects it before provider work; altered target bytes remain unchanged by Latest |
| Unchanged signed targets still update | passed | Real signed Sparkle installation reaches 1.1.0 (2); deep/strict code signing and actual post-install UI verify result |
| Other instances/providers stay unchanged | passed | Same-ID secondary Sparkle and Homebrew controls remain byte-for-byte unchanged in negatives and valid selected-instance case |
| Evidence and README | passed | Native xcresults, source hashes, environment, mutation preconditions, journals and preserved target/control results retained; README links reproduction |

Fast signing metadata is identity evidence, not full cryptographic validation.
Before installation, a present signature must pass strict validation for every
architecture; identity is read again afterwards. Unsigned hosts remain supported
where the update provider separately establishes provenance. The signature check
applies to all install paths; positive Store acceptance still needs its real target.

Evidence: `.build/native-install-tests/evidence/l51/{replacement,tampered}/`
contains native log, unique xcresult and result.json. The positive case retains
L05 `valid` evidence at this exact source. No production app is altered. This
does not prove every race after installer handoff; directory/volume/generation,
privileged receipt and production release gates remain separate.
