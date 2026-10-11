# Test coverage and evidence

## Original headless extraction evidence (historical)

At `78c4548`, 23 deterministic Swift test functions pass without GUI automation,
including 12 application workflows. One additional native Sparkle test is
explicitly skipped in default/CI runs; it is executed separately in the
[actual four-case native suite](headless-native-acceptance.md). Each native case
also passes in a newly spawned restart process. Current checks include 84
compiled invariants, seven feed/signature regressions, 74 English/German keys and
warnings-as-errors Debug/Release builds. Xcode MCP reports 23 passing selected
LatestCoreTests and zero failures/skips; it does not run the UI target.

Application policy and jobs live in LatestApplication, with a SwiftUI wrapper
and a shared native runtime for the future CLI. CI builds/packages the wrapper
and tests the core without XCUITest. The source-boundary validator forbids GUI/
platform imports in LatestCore and LatestApplication. Native installation tests
use real adapters; injected workflow tests do not stand in for installations.

The sections below retain historical UI/provider evidence from before this
extraction. Their result bundles remain useful, but fresh final acceptance of
remaining scenarios must use the shared API or a separate manual native check.


## Current direct native Sparkle lifecycle

[Three actual lifecycle cases](headless-lifecycle-acceptance.md) pass at 7f43333:
real gated download/cancellation, HTTP 503/retry, and a natively registered stopped
app during installer handoff. Exact terminal journals, unchanged pre-recovery
bytes/other instances, signed 1.1.0 and separately spawned restart processes
accompany the state checks. All five Homebrew and four other Sparkle native cases
also pass at the same current test-source revision. Default runs execute 24
functions and skip the three separate native opt-ins; those skips are not proof.

## Current direct native Homebrew verification

[Five actual Homebrew cases](headless-homebrew-acceptance.md) pass at 01939db
through the production session/runtime, followed by five new-process restarts.
The unchanged-identity ownership-loss case reaches fresh provider validation;
the changed-instance case fails preflight before any upgrade process. Real
checksum failure/retry and HTTPS catalogue denial preserve controls and the
ordinary registry/Ruby runtime. The new real process-stream test ensures
successful stdout JSON survives unrelated stderr warnings while diagnostics
retain the aggregate output limit. Default Swift tests execute 24 functions and
skip only the two explicit native opt-ins. The four signed native Sparkle cases
also pass again after this shared process-adapter change.

## Frozen release source verification

[source-release-acceptance.md](source-release-acceptance.md) records the actual
archive rebuild at 56a593b and its green main CI. Seven additional source/binding
contracts bring the Python release suite to 14. They execute real temporary Git
exports and reject dirty/staged/untracked/private input, changed original HEAD,
source modification/injection, external symlinks, mismatched metadata and a
nonaccepted notary report. The production release orchestration test simulates
its external signer/notary commands; it does not prove real notarization.
Actual build, existing development signature, licence bytes, source hash
preservation and pinned dependency/patch restoration are checked separately.

## L19 native directory and volume evidence

[Four controlled actual cases](directory-acceptance.md) passed at `53dc1df`,
including the final generation guards. Native
NSOpenPanel addition, toggles/removal, persisted exact exclusions and normal
quit/restart accompany actual populated/empty image ejection and remount. A real
held signed HTTPS response released after directory removal cannot restore a
stale row. All scanned/control bundles stay unchanged and no install job starts.

## Native executable-instance integrity

[#51](instance-integrity-acceptance.md) at `379cacc` verifies two real preflight
rejections with unchanged metadata/times and a real positive signed installation.
Native journals prove rejection before provider work; independent signing checks
establish valid replacement versus intentionally invalid tampering.

## L18 normal signed migration evidence

[Two actual normal-start cases](migration-acceptance.md) at `253eafa` use a
separate filesystem home and real isolated CFPreferences suite. They verify
first migration, native settings switches, normal Command-Q/relaunch, nonrepeated
migration and malformed/missing defaults. No synthetic inventory or native
installation mode is used; all source/isolation limits and cleanup hashes are
documented explicitly.

## L17 native major and bulk evidence

[Four actual native cases](major-bulk-acceptance.md) at `11d08a6` verify major
cancel/consent, explicit provider-major policy, changed-consent rejection and
bulk eligibility with two real signed installations and unchanged excluded apps.
Controlled real HTTPS gates prove scan-time and duplicate-job protection. The
installed version's live native accessibility value is checked after replacement.

## L16 native preference evidence

[Two actual native cases](app-preferences-acceptance.md) at `2743f68` cover
ignore/reversal, concrete skip/clear/restart, a later real appcast version and
instance-scoped Stable/Beta checks across relaunch/refresh. The driver verifies
saved canonical-path keys independently and unchanged selected/secondary/other-
provider bundles. These are production provider checks, with no injected inventory.

[L15](ui-filter-sort-acceptance.md) adds current native evidence on `b61f414`:
every source/reset, combined status visibility, both stable sort orders and
exact duplicate-instance selection across changed scan enumeration. The entire
ordinary suite passes seven UI tests plus seven Swift contracts; real provider
checks and installation cases retain their separate environments and evidence.

## L07 native compatibility evidence

[Four actual native cases](sparkle-compatibility-acceptance.md) at `776c4b2`
check a signed x86_64 archive on arm64, target minimum OS 99, a real signed
incomparable build, and Sparkle build ordering with display-version disagreement.
Rejected cases start no job and preserve exact selected app bytes. The successful
case independently verifies installed bundle identity/version, signature and
actual Mach-O architecture, plus native restart and unchanged control instances.

## L06 native Sparkle lifecycle evidence

At `ffb4ea0`, [three opt-in native cases](sparkle-lifecycle-acceptance.md) exercise
stalled HTTPS cancellation, HTTP 503/retry and delayed running-app termination
at installer handoff. Job journals show one terminal outcome; disk digests prove
no pre-retry mutation and unchanged same-ID/other-provider controls. Retries
install signed 1.1.0; native restart retains the observed version/status. Three
additional Swift Testing contracts exercise actual adapter late callbacks and
old-token rejection, bringing that suite to ten tests.

`LatestVerification` executes production core/adapter code with controlled
fixtures on macOS 27. It performs no root installation and no user-app update.
`LatestCoreTests` provides the Xcode Swift Testing suite; `LatestUITests` uses
the real native SwiftUI views with an isolated debug fixture inventory.
The separate [native installation fixtures](native-fixtures.md) prepare signed
baseline/target bundles and an isolated real Homebrew cask. Their preparation
and HTTPS checks do not replace the remaining provider installation acceptance.

| Behaviour / audit finding | Automated evidence | Remaining acceptance |
|---|---|---|
| A01 shell interpolation | Literal quote/metacharacter argument process test | None for removed shell sink |
| A02 unrestricted root request | Numeric-ID/duplicate/path policy; root payload, scripts and traversal tests | Native signed peer, file-race and positive package tests |
| A03 dependency updates | Exact distribution digest and source revision, compiled Sparkle 2.10 / mas v7 | Controlled signed Sparkle update |
| A04 versions | Equality/hash, symmetry, interior zeros, prerelease, calendar, Unicode, large integers, unknown values | Provider-specific real app fixtures |
| A05/A10 remote parsing | Malformed plist, invalid cask neighbours, empty minimum OS | Live upstream changes |
| A06 instance identity | Canonical registration, unowned same-name app rejection, uncached Info.plist reads | Duplicate App Store installation on real volume |
| A07 reply lifecycle | Concurrent completion races, reply before waiter, late terminal events | Native XPC disconnect/timeout |
| A08 cancellation | Reaped process groups, owned preflight cancellation, safe installer handoff | Controlled real package cancellation |
| A09 progress | Monotonic phases and terminal-state protection; main-actor adapter build | Native Sparkle lifecycle |
| A11 Homebrew | Real v2 schema and exit-1 regression; actual native update, provenance loss, changed-instance rejection, informational catalogue and real failure/retry; unchanged controls | Default-prefix, arbitrary-cask and other-architecture coverage |
| A12 network/cache | HTTP rejection, status, body bound, downgrade rejection, malformed body and stale good cache | Native TLS/server behaviour |
| A13 inventory | Missing/disabled folders, current metadata, superseded generations | External volume/device events |
| A14 UI | Five native XCUITests passed on 2731361; exact cases below | Source filtering/sorting, skip/channel/major/bulk interactions; VoiceOver, keyboard and large text |
| A15 release trust | Foreign signer rejection, requirement injection, Ed25519 valid/tampered signatures, signed feed envelope | Developer ID/notarization/self-update |
| A16 modern checks | Both Xcode 27 runs on 2731361 passed all workflow steps, seven Swift tests and five native UI tests | Re-run affected checks when implementation changes |
| Filtering / ignored / skipped / channels | Production resolution and presentation tests | UI interactions |
| Migration / persistence | One-time legacy migration, save/reload, missing new fields | Restart of normal signed app |
| Architecture | Mach-O headers and explicit incompatible feed/archive URLs | Actual installed executable after update |
| Release notes | Removed active markup, plain text, bounded response | Large text, accessibility and resizing |

Test counts and final-head results are recorded in acceptance.md. A source
contract test is not a substitute for any native acceptance cell above.

The additional opt-in `testNativeHomebrewUpdate` has passed locally under
Xcode 27 against the signed real fixtures. It is skipped when the explicit
fixture environment is absent; the five earlier UI tests retain their original
scope. [L03 evidence and criteria](homebrew-native-acceptance.md) describe the
real update, its retained xcresult and its isolated-prefix limits.
The four additional opt-in [L04 native cases](homebrew-native-rejection.md)
exercise the real installation boundary and error recovery. All five native
installation tests require explicit fixture setup; ordinary CI still checks the
five standard UI behaviours and skips those installation cases.

## Native UI evidence for 2731361

Verified implementation: `273136101412f767c02d40291bc08a456c2200b8`.
Both [PR run 37988080394](https://github.com/mpwg/Latest/actions/runs/37988080394)
and [push run 37988071896](https://github.com/mpwg/Latest/actions/runs/37988071896)
passed on macOS 27 with Xcode 27.0 / Swift 6.4. Logs and downloaded artifacts
were inspected on 2026-10-10. Their `native-tests.xcresult` bundles are in the
[PR artifact](https://github.com/mpwg/Latest/actions/runs/37988080394/artifacts/11644028271)
and [push artifact](https://github.com/mpwg/Latest/actions/runs/37988071896/artifacts/11643464628).

| Native test | Observed behaviour | Limit |
|---|---|---|
| testSelectionAndPlainReleaseNotes | Select the identified fixture row; plain fixture notes and update button appear | Does not activate an installer or fetch remote notes |
| testSearchFiltersAndRestoresInventory | An unmatched search hides the row; clearing it restores the row | Does not test source filters or sorting |
| testIgnoreIsPersistentAndHidesRow | Ignore the fixture, terminate and relaunch with the same isolated preferences; row remains hidden | Does not test normal signed-app startup or legacy migration |
| testGermanInterface | German launch shows the expected localized empty-selection label | Does not establish complete German interaction or VoiceOver |
| testAccessibilityIdentifiersAndScreenshot | Refresh button is found; native window screenshot is attached | Identifiers and screenshots do not prove screen-reader, keyboard or large-text acceptance |

The suite reports five tests and zero failures in each run. All use the real
native views with `--ui-testing`, one controlled debug inventory and isolated
preferences. The existing suite does not establish provider installation,
privileged XPC behaviour, source filtering/sorting, version skipping, channel
selection, major/bulk update actions or complete accessibility. Those remain
separate acceptance tasks in the [work overview](https://github.com/mpwg/Latest/issues/5).
