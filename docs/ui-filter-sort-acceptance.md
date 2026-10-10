# Native filters, visibility and sorting — L15 (#20)

Verified implementation `b61f414`, 2026-10-10, macOS 27.0.1, Xcode 27.0 /
Swift 6.4, arm64. The client and XCTest runner use the own Development signing
identity with actual TeamIdentifier `PZV43D6HWT`.

The opt-in debug `--ui-testing-matrix` inventory has nine read-only records:
all five sources, current/available/external/unknown/incompatible/ignored/skipped
states, and two same-name/same-ID Twin instances at distinct canonical paths.
Each rescan alternates their input enumeration order. Tests initialize their
own preferences file so unrelated legacy settings cannot affect expectations.
These fixtures exercise actual native SwiftUI views and the production
Presentation filter/sort and preference-save paths. They perform no provider
check or installation.

Integration recheck at `4e77913` on 2026-10-10 (same environment/signing team):
both source-filter and visibility/stable-instance-sort XCUITests passed again,
zero failures, after integrating current L05/L28 main changes. Retained evidence:
`.build/l15-current/filter-sort.xcresult`, `native-tests.log` and
`source-evidence.json`. The warnings-as-errors Release build, 84 compiled
invariants, seven Swift Testing contracts, 74 localization keys and all seven
appcast/signature regressions passed on that integrated source. The appcast
regression requires building the current LatestRelease Debug tool first;
an existing binary from another branch is not current evidence.

After integrating L06, `271adc9` passed both native filter/sort tests again
(`.build/l15-current/filter-sort-with-l06.xcresult`, accompanying native log).
The complete three-case real Sparkle lifecycle driver also passed on that
same combined source, preserving controls and exactly one terminal result per
job. Current supporting checks: 84 compiled invariants, ten Swift Testing
contracts, seven appcast regressions, warnings-as-errors Release build and
74 localization keys. This verifies both implementations coexist.

## Reproduce

With full Xcode 27 and an own Apple Development identity/team:

```sh
xcodebuild -project Latest.xcodeproj -scheme Latest -destination 'platform=macOS' \
  -derivedDataPath .build/l15-xcode -resultBundlePath .build/l15-repeat.xcresult \
  -only-testing:LatestUITests/LatestUITests/testEverySourceFilterAndReset \
  -only-testing:LatestUITests/LatestUITests/testVisibilitySettingsAndStableInstanceSorting \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=YOUR_IDENTITY DEVELOPMENT_TEAM=YOUR_TEAM test
```

Use a fresh result-bundle path for each run. Both tests also run in ordinary CI.
Local ad-hoc XCTest runners can fail library validation before executing tests;
that failure is not acceptance evidence. Use the available own signing identity.

## Criteria matrix

| Criterion | Status | Current native evidence |
|---|---|---|
| Every source filter and its reset | passed | Native pop-up selects App Store, Homebrew, Sparkle, Catalogue Hint and Unknown Source; asserts exact ordered canonical paths, then restores All Sources after every selection |
| Current/ignored/skipped/unknown/incompatible visibility | passed | Native Settings switches remove current rows, reveal both ignored/skipped rows and remove both unknown/incompatible rows; each combination asserts exact paths |
| Name/path and source order with duplicate names | passed | Both orderings asserted for all nine records, including A/Twin before B/Twin; repeated scans change enumeration order without changing presentation order |
| Selected canonical instance survives settings and scans | passed | Select B/Twin through its native row; detail retains its exact path after visibility/source/name sorting and both rescans |
| Current evidence and README | passed | Full suite on b61f414: seven native UI tests, seven Swift Testing contracts, zero failures; 84 compiled invariants, warnings-as-errors Release build, 74 localization keys; README links this procedure |

Retained final evidence:
`.build/l15-evidence/native-tests-final.xcresult`, `native-tests-final.log`,
`invariants-final.log` and `source-evidence.json`. The result bundle contains an
actual window screenshot with all states and the selected B/Twin path.
Five opt-in Homebrew installation checks are skipped in this ordinary UI run;
they are not counted as passed installation evidence.

The tests exposed and fixed Unknown Source excluding records without a candidate.
Filtering and sorting now normalize absent candidates to `.unknown`; equal-source
records retain the name/path tie-breaker. The row's accessibility value includes
its canonical path so duplicate instances can be distinguished.

Channel/skip persistence, major/bulk actions, normal signed legacy migration,
keyboard/VoiceOver and large-text acceptance remain separate packages.
