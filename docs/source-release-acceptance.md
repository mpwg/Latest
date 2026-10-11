# Frozen release sources and rebuild evidence (L30 / #35)

Implementation checked at `56a593b7c3e0cc2f983dea0089761b8804625ff6`, on
2026-10-11, macOS 27.0.1 / Xcode 27.0 / Swift 6.4 / arm64. Main CI
[38153797844](https://github.com/mpwg/Latest/actions/runs/38153797844) passed at
this exact commit. The controlled archive rebuild also uses this exact revision,
without a .git directory in the exported source.

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
`.release/source-preparation/1.0.0-56a593b7c3e0-1skad2gn/`.
Archive: **918862 bytes**, SHA-256
`422b3a73f9149868db5820e5325823eba76c7d4b9acec7925be7b66ecdb01328`.
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
| Headless Swift tests | 23 deterministic functions passed; separate native opt-in skipped as intended |
| Compiled production invariants | 84 passed |
| Source/metadata and signed-feed regressions | 14 passed; notarization subprocesses are simulated in these contract tests only |
| Localization and boundary validation | 74 English/German keys and project/source checks passed |
| Controlled development packaging | Exact source commit above, version 1.0.0, build **1458** in the actual signed Info.plist |
| Licence and source comparison after packaging | All exported source hashes unchanged; GPL/Sparkle/mas notice bytes match their pinned input |
| Real signature and executable | Deep/strict verification passed; actual Apple Development signer/team PZV43D6HWT and arm64 executable independently inspected |

Packaging reused the existing approved Apple Development identity. It did not
create a certificate, register a broker, launch GUI automation, update an installed
application, read the production update seed or contact notarization. The 1.0.0
label belongs to this controlled rebuild; it does not authorize a release version
or publication.

The directory retains source.tar.gz, source-manifest.json, source-revision.txt,
bootstrap.log, release-build.log, swift-tests.log, invariants.log,
release-tests.log, validation.log, development-package.log and rebuild-result.json.
The JSON records environment, exact revision/build/archive, observed flow, actual
signer/architecture, unchanged-source/licence checks and all log hashes.

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
