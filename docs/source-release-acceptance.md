# Frozen release sources and rebuild evidence (L30 / #35)

Archive rebuilt at `d62818494971831309b1329999c05145a96850f0`, on
2026-10-12, macOS 27.0.1 / Xcode 27.0 / Swift 6.4 / Python 3.15 / arm64.
The controlled archive rebuild uses this exact revision, without a .git
directory in the exported source. Both CI jobs pass at
[4422057 / 38178452561](https://github.com/mpwg/Latest/actions/runs/38178452561),
with the same implementation/test sources; `d628184` changes CI assessment
documentation only. Its separate CI run is
[38179000708](https://github.com/mpwg/Latest/actions/runs/38179000708).

## Implemented boundary

Release input must be the clean repository root. One immutable commit produces
one build number and one source archive. Compilation, packaging, key comparison
and signed-feed operations use the extracted source workspace. Packaging gets
explicit build/source metadata; an exported tree cannot borrow its parent's Git
history. After build, the original checkout and exported source hashes are
checked again. Dirty input, a changed HEAD, added/modified source, conflicting
bundle metadata or a non-Accepted notary report abort preparation.

The production path checks exact version/build/source metadata and licence
bytes, requires accepted notarization, successful stapler validation and
Gatekeeper assessment, signs the final stapled archive and merged feed, and
validates the whole feed. The final directory excludes the build workspace,
private/generated inputs and unsigned intermediate feed. Existing prepared
versions are never overwritten. The artifact manifest records hashes/lengths,
source commit, version/build, dependency pins, patch hashes and actual toolchain.

## Actual source archive rebuild

Source-only preparation:

```sh
python3 scripts/release.py --version 1.0.0 --prepare-source-only
```

Retained directory:
`.release/source-preparation/1.0.0-d62818494971-nzdvgsd0/`.
Archive: **974761 bytes**, SHA-256
`019f3224c8db5b202f4423588720b3225df427e170d372bf146c2a03b8cc69e4`.
It contains only committed source files; no .git, Vendor, .build or private
.release data. The source manifest retains every source hash plus dependency
pins and the two reviewed mas patches. A checksum-verified Sparkle ZIP cache was
copied as a distribution cache; its framework was independently extracted and
mas/pinned packages were freshly bootstrapped in the exported workspace.

Observed in that workspace:

| Flow | Actual result |
|---|---|
| Bootstrap exported pins and reviewed patches | Sparkle distribution checksum and mas exact source revision verified; both applicable patches applied; actual mas compiled |
| Release build with warnings as errors | passed |
| Headless Swift tests | 35 regular functions passed; nine isolated native opt-ins explicitly skipped in the exported workspace |
| Compiled production invariants | 84 passed |
| Source/metadata and signed-feed regressions | 14 passed; notarization subprocesses are simulated in these contract tests only |
| Localization and boundary validation | 85 English/German keys and project/source checks passed |
| Controlled development packaging | Exact source commit above, version 1.0.0, build **1506** in the actual signed Info.plist |
| Licence and source comparison after packaging | All exported source hashes unchanged; GPL/Sparkle/mas notice bytes match their pinned input |
| Real signature and executable | Deep/strict verification passed; actual Apple Development signer/team PZV43D6HWT and arm64 executable independently inspected |

Packaging reused the existing approved Apple Development identity. It did not
create a certificate, register a broker, launch GUI automation, update an installed
application, read the production update seed or contact notarization. The 1.0.0
label belongs to this controlled rebuild; it does not authorize a release version
or publication.

The first packaging attempt could not resolve the certificate's non-ASCII
display name. The retained failed log records that result. Retrying with the
existing certificate's SHA-1 identifier
`F2DB5A6D5AF5BAD3F219ED222128B7B09956A2FA` succeeded; actual signature inspection
confirmed the same signer and team. No certificate/key/trust was changed.

The directory retains source.tar.gz, source-manifest.json, source-revision.txt,
bootstrap.log, release-build.log, swift-tests.log, invariants.log,
release-tests.log, validation.log, development-package.log,
development-package-retry.log, rebuild-progress.json and rebuild-result.json.
The JSON records environment, exact revision/build/archive, observed flow, actual
signer/architecture, unchanged-source/licence checks and all log hashes.

The earlier `56a593b` rebuild remains retained separately as historical evidence.
It used build1458 and 23 regular functions/74 translations; it does not replace
the current shared-session/runtime/GUI source rebuild above.

## Criteria and remaining prerequisites

| Criterion | Status | Evidence / next step |
|---|---|---|
| Clean immutable source input and fixed build identity | passed | Actual Git-export regressions, source-only export and actual packaged source/build/version |
| Rebuild from archive with documented pins and patches | passed | Fresh exported workspace above, actual bootstrap/build/tests and unchanged source manifest |
| Licence notices and exclusion of private/generated source inputs | passed | Actual archive listing/manifest, actual development package licence byte comparison and private-input rejection regressions |
| Actual production archive/appcast/notary metadata agreement | open | Binding logic and negative contracts pass; Developer ID/notary/update credentials are still deferred |
| Final signed/notarized artifact set and restored production build | not verifiable | Prepare/verify the actual production set once credentials and remaining native gates are available |
| Current README/test/acceptance documentation | passed | README, releasing.md, this record and current matrix |

**L30 is not fully accepted.** The controlled Apple Development rebuild is not
production Developer ID, notarization, Gatekeeper distribution or self-update
proof. #35 therefore remains open alongside #30–#32 and #34. No release or tag
was published. Publication still requires explicit owner approval.
