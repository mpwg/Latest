# Test coverage and evidence

## Native production networking and cache

[L23 network acceptance](native-network-acceptance.md) at `ecae2d0` runs thirteen
actual native subprocesses using every compiled LatestCore source and its
production TLS session. It fetches the current real 19.1 MB Homebrew catalogue,
isolates valid/invalid neighbours, rejects certificate mismatch and HTTPS
downgrade, preserves a good cache across real status/JSON/stream errors, cancels
an active stream, and verifies offline recovery in a new process. Expired,
corrupt and oversized offline caches are rejected. Independent server/cached
byte/time/app-file checks accompany the current source-hash-bound JSON.
The existing certificate/trust is reused; no GUI automation or installation
occurs. macOS CI compiles the opt-in harness; default CI does not alter trust.

## Current archive rebuild

The [frozen-source rebuild](source-release-acceptance.md) at `d628184`, checked
on 2026-10-12, uses a fresh extracted archive without .git or prebuilt Vendor
dependencies. Actual bootstrap, warnings-as-errors Release compilation, 35
regular Swift functions (nine explicit native skips), 84 invariants, fourteen
release/feed tests and 85 translations pass. The development-signed bundle
carries exact build1506/source metadata and arm64; source hashes and pinned
licence bytes remain unchanged. The same approved certificate is selected by
its fingerprint after a display-name lookup failure. This is archive-rebuild
evidence, with production signing/notarization/self-update still open.

## Shared host self-update entry and current regression

At `0d6728f`, four new [host self-update tests](shared-self-update-acceptance.md)
run the production session without a GUI/SDK controller. All 35 regular Swift
functions pass, with nine explicitly skipped default native opt-ins. The native
host controller moved from the GUI into the shared runtime; startup, capability,
reentrant request ownership, ordinary-job exclusion and error/retry are shared.
The validator rejects Sparkle imports in GUI sources as well as GUI/platform
imports in the core/application modules.

All nine actual native drivers were rerun after the protocol/session/runtime
change. The 37 current JSON source maps match, including actual provider
installations/rejections/restarts, settings/migration, real volume actions and
native signed broker/client boundaries. Debug/Release/Xcode builds, 84 invariants,
fourteen source/feed tests, 85 translations and
[Ubuntu/macOS CI](https://github.com/mpwg/Latest/actions/runs/38177801106) pass.
This does not prove a production host self-update or replace locked-host native
UI acceptance. Private logs/index: `.build/shared-self-update-native-regression/`.

## Native interactive lifecycle

[Lifecycle UI acceptance](native-ui-lifecycle-acceptance.md) at `77e9b92` records
actual native English Cancel, HTTP503 failure, valid retry, installer handoff and
main-window/application guards through the same shared session. Independent
journals show cancelled/failed/succeeded primary-only jobs, strict signed1.1
arm64 installation and unchanged three control byte maps. The selected running
fixture's exact NSWorkspace identity and stopped process are checked before
handoff recovery. No injected installer is used.

The follow-up `b59d5e9` presents cancellation neutrally and labels progress AX.
Current local Debug/Release/Xcode, 31 regular Swift functions with nine explicit
native skips, fourteen Python tests and 85 translations pass; actual
[Ubuntu/macOS CI](https://github.com/mpwg/Latest/actions/runs/38176553024) passes.
The current German GUI restart cannot yet be observed: CUA requires owner unlock
of the locked Mac. Builds/CI do not replace that remaining native acceptance.

## Native interactive UI repairs

[Native UI acceptance](native-ui-acceptance.md) records actual signed macOS
English/German interactions, repaired selected-instance AX, shortcuts, 100%/160%
ordinary content/control fonts and five channel keyboard cycles at `44c6958`.
Two cycles preserve native focus across a real refresh; one also crosses the
production monitor interval. Read-only JSON proves primary-only Beta/Stable
persistence; all four signed fixture byte maps remain unchanged. This is
interactive acceptance, separate from GUI-free correctness tests. VoiceOver,
narrow/minimum windows, long notes and update dialogs remain open.

Current relevant local checks pass: Debug/Release with warnings as errors,
Xcode MCP build, 31 regular Swift functions with nine explicit native default
skips, fourteen Python source/feed tests and 84 English/German keys. All 37
current native core result source maps still match; GUI changes did not modify
those implementation/test sources. Actual Ubuntu/macOS CI passes at
[71d88c4](https://github.com/mpwg/Latest/actions/runs/38173445248); the later
focused native adapter change requires its own current CI.

## Ubuntu CI split

At `4422057`, [both CI jobs](https://github.com/mpwg/Latest/actions/runs/38178452561)
pass. The [portable Ubuntu job](ci-platforms.md) passes thirteen Python
tests and source/localization/resource checks on actual Ubuntu 24.04 with
CPython 3.14.8. Six history tests and seven source/artifact contracts require no
Apple SDK; all 85 EN/DE keys pass. The actual signed-feed test remains in macOS CI; local full discovery
still executes all fourteen tests and passes. Swift/native/Xcode/package checks
remain on macOS, gated on portable success. No native acceptance criterion is
replaced by this Linux run. The renewed assessment on 2026-10-12 identifies the
injected shared application tests as further Linux candidates, with concrete
package, cryptography, network and test-target separation prerequisites. It does
not claim a Swift Linux build. The actual Ubuntu log is retained at
`.build/ubuntu-ci-assessment-4422057.log`.

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


## Current shared Store queue and regression run

At `ead2e13`, [six exclusive Store workflow tests](store-queue-acceptance.md)
pass through the production session with injected capabilities. Waiting ownership
spans verification, actual registered waiters cancel before the active job ends,
failure/verification failure release the next job, changed/ignored queued offers
fail before installation and other providers continue independently. These
workflow tests do not establish actual privileged Store installation.

All thirty-seven prior native scenarios pass again at this revision, and every
relevant result source hash matches. Default tests execute 31 deterministic
functions and skip nine native opt-ins; Xcode MCP selects 31 functions with zero
failures/skips. Warnings-as-errors Debug/Release, 84 invariants, fourteen Python
tests and 74 localized keys pass. Evidence includes `.build/store-queue-tests.log`,
`.build/headless-regression-after-store-queue.log`,
`.build/headless-broker-boundary-after-store-queue.log`,
`.build/store-queue-native-evidence.json`, and `.build/store-queue-xcode-evidence.json`.

## Broker client boundaries and regression run

At `e75ed99` (driver `ead92fc`), [nine native client/resource cases](headless-broker-boundary-acceptance.md)
pass with actual development-signed bundles and native Security/NSXPC APIs.
The unavailable-service case exposed a SIGTRAP in the MainActor-inferred proxy
error callback; nonisolated Sendable factories fix it and two actual failed
connection attempts now finish cleanly. Malformed ID/identifier/path requests
are rejected before host validation or XPC. Preflight hashes/signatures run off
MainActor with cancellation, and first-tool cleanup is owned before verifier staging.

These are client/resource checks; root peer authentication, staging ownership,
handoff/disconnect/timeout and authentic Store installation remain open. Shared
Store bulk serialization also remains open. All twenty-eight prior native
scenarios pass again; thirty-seven current source maps match relevant files.
Default tests execute 25 deterministic functions and skip nine native opt-ins;
Xcode MCP runs 25 selected functions with zero failures/skips. Debug/Release
warnings-as-errors, 84 invariants, fourteen Python tests and 74 localized keys pass.
Logs: `.build/headless-broker-boundary-all.log`,
`.build/headless-regression-after-broker.log`, `.build/broker-current-native-evidence.json`
and `.build/broker-xcode-evidence.json` with its native xcresult.

## Native directories, migration and regression run

At `1dd0240`, [four native directory/volume cases](headless-directory-acceptance.md)
and [two real legacy/JSON migration cases](headless-migration-acceptance.md) pass.
Actual images are ejected/remounted, production monitoring recovers populated
and empty volumes, and the obsolete real HTTPS scan is drained after a newer
generation removes its directory. Every directory case passes in a fresh process.
Five fresh migration processes use actual isolated CFPreferences and real JSON;
only inventory/provider capabilities are scoped to the private profile.

The production legacy reader moved from GUI startup into LatestCore, shared with
the future CLI. Changed old values cannot overwrite migrated/edited settings;
malformed values produce defaults. Ordinary domain/file hashes and all controlled
app bytes remain unchanged. No preferences timestamp is restored and all owned
volumes are detached after acceptance.

All twenty-two previous native cases also pass again on this revision; twenty-eight
result maps match every relevant source hash. Default tests execute 24 deterministic
functions and skip eight native opt-ins. Xcode MCP builds the test targets and
runs 24 selected functions with zero failures/skips. Debug/Release warnings-as-errors,
84 invariants, fourteen Python tests and 74 localized keys pass. Evidence includes
`.build/headless-regression-after-migration.log`, `.build/headless-migration-all.log`,
and `.build/migration-xcode-evidence.json` with its native xcresult.

## Direct native major/bulk and regression run

[Four actual major/bulk cases](headless-major-bulk-acceptance.md) pass at
`ed5d42e`, with four separate restart processes. Real signed semantic/provider
major targets require consent; cancellation starts no job. A changed provider
requirement fails before archive download. Actual held HTTPS scans/downloads
prove command guards and duplicate rejection. Exactly two authorized minor
paths install once; excluded apps preserve their exact bytes.

All eighteen other native cases and their fresh processes also pass again on
this revision. All twenty-two result source maps match current relevant files.
Default tests execute 24 deterministic functions and skip six native opt-ins;
Xcode MCP runs 24 selected functions with zero failures/skips. Warnings-as-errors
Debug/Release, 84 invariants, fourteen Python tests and 74 localized keys pass.
Logs: `.build/headless-major-bulk-all.log`,
`.build/headless-regression-after-major-bulk.log`, and
`.build/major-bulk-xcode-evidence.json` plus its native xcresult.

## Direct native preferences and regression run

[Two actual preferences scenarios](headless-preferences-acceptance.md) pass at
`2463621` through nine fresh shared-session processes. Ignore/reversal, visibility,
exact-instance/version skip/clear/new-version behavior and Stable/Beta persistence
use real signed apps/HTTPS feeds and independently checked JSON. No installation
job starts and all controlled app bytes stay unchanged. All sixteen other native
cases and their sixteen fresh restart processes also pass again at this revision;
all eighteen result source maps match the current relevant files.

Default Swift tests execute 24 deterministic functions and skip five native
opt-ins. Xcode MCP builds test targets and selects 24 functions with zero
failures/skips. The native preference opt-in is discovered in the existing test
target. The Xcode MCP project serialization preserves all project objects and
settings. Local warnings-as-errors Debug/Release, 84 invariants, 14 Python release
regressions and 74 localized keys pass. Aggregate logs are retained under
`.build/headless-preferences-all.log` and `.build/headless-regression-after-preferences.log`.

## Direct native compatibility and regression run

[Four real signed compatibility cases](headless-compatibility-acceptance.md)
pass at `d6505ff`, each followed by a fresh process restart. They check an actual
x86_64 enclosure on arm64, a macOS 99 target, an incomparable signed installed
build, and actual Sparkle installation of 0.9.0 (2) over 1.0.0 (1).
Default Swift runs execute 24 deterministic functions and skip four native
opt-ins. The selected Xcode MCP core run before this additional opt-in passed
24 functions with zero failures/skips; the native wrapper also built.

All five Homebrew, four other Sparkle and three lifecycle cases also pass again
at this revision, with twelve further fresh process restarts. All sixteen
private result source maps match the current relevant files. Warnings-as-errors
Debug/Release, 84 invariants, 14 Python release regressions and 74 localized keys
pass. The retained local aggregate log is `.build/headless-regression-after-compatibility.log`.

## Direct native Sparkle lifecycle

[Three actual lifecycle cases](headless-lifecycle-acceptance.md) pass at 7f43333:
real gated download/cancellation, HTTP 503/retry, and a natively registered stopped
app during installer handoff. Exact terminal journals, unchanged pre-recovery
bytes/other instances, signed 1.1.0 and separately spawned restart processes
accompany the state checks. All five Homebrew and four other Sparkle native cases
also pass at the same current test-source revision. Default runs execute 24
functions and then skipped three separate native opt-ins; those skips are not proof.

## Direct native Homebrew verification

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
| A12 network/cache | Deterministic contracts plus native-network-acceptance.md: actual TLS, downgrade/status/stream/JSON rejection, current provider sample and offline restart | Native network/cache proof passes; full UI freshness presentation remains separate |
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
