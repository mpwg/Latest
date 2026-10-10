# Native Sparkle compatibility — L07 (#12)

Observed on 2026-10-10 at `776c4b2`, macOS 27.0.1 / Xcode 27.0 / Swift 6.4,
arm64 host. Own Apple Development-signed client, runner and test bundles
use team `PZV43D6HWT`. Checks use the real Sparkle adapter, actual inventory
and native SwiftUI controls; rejected cases do not inject a provider result.

## Reproduce

Prepare the [native fixtures](native-fixtures.md) and their HTTPS server with
previously approved localhost trust, then run:

```sh
python3 scripts/native_sparkle_compatibility.py all
```

The driver creates separately signed controlled target bundles/archives,
signs the archive and complete appcast with the fixture-only Ed25519 key,
and always restores the original feed. Certificate hashes resolve the signing
identity without relying on command-line display-name Unicode conversion.
Prepared targets remain under `evidence/l07/prepared/`; archives stay in the
disposable web directory. No production release credentials are required.

## Criteria matrix

| Criterion | Status | Actual observed native result |
|---|---|---|
| Explicitly incompatible architecture rejected before installation | passed | Cross-compiled signed x86_64 executable in an explicitly x86_64 enclosure on arm64; native UI displays architecture rejection, disables Update; selected bundle unchanged and no installation job starts |
| Excessive minimum OS rejected before installation | passed | Signed target bundle and appcast require 99.0; native Incompatible Update and newer-OS reason; no job and unchanged selected bundle |
| Incomparable real versions remain unknown | passed | Real signed baseline CFBundleVersion is 🚀; appcast build 2; native Status Unknown with comparison reason and disabled Update; unchanged exact bundle, no job |
| Actual display/build values obey provider policy | passed | Signed baseline 1.0.0 (1), signed target 0.9.0 (2); production Sparkle policy uses build 2 and installs target; native relaunch still shows 0.9.0 (2), Up to Date |
| Post-install identity, signature and executable architecture | passed | Independent Info.plist matches exact selected bundle ID/display/build; deep/strict codesign check and lipo report the installed arm64 executable; one actual succeeded job |
| Other instances remain unchanged | passed | Same-ID secondary Sparkle instance and Homebrew fixture remain byte-for-byte unchanged in all four cases |
| Evidence, environment and README | passed | README links reproduction; result.json records source revision/hashes, native xcresult, canonical path, actual target/installed architectures, versions, minimum OS and job events |

All four individual XCUITests passed with zero failures. Evidence is retained
at `.build/native-install-tests/evidence/l07/{case}/` (`native-tests.log`,
unique `native-tests-*.xcresult`, `result.json`). Supporting checks pass:
warnings-as-errors Release build, 84 compiled invariants, ten Swift Testing
contracts, seven appcast regressions and 74 English/German keys.

The architecture negative case proves rejection of an explicit architecture
target; it does not establish every generic vendor archive's architecture
selection. The tested host is arm64. An Intel-host run has not been performed.
Authentic App Store receipts/packages and production release acceptance remain
separate open requirements.
