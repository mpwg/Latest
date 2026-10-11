# Acceptance matrix


## Current run: shared core, no GUI automation

Owner amendments on 2026-10-11: application logic belongs in a GUI-independent
core shared with a later CLI; automated tests run without GUI automation;
direct work/commits on main are authorized, without PRs yet. Reuse the approved
localhost certificate/trust until its natural expiry on 2026-10-17.

Checked application/runtime/test code: `0d6728f`, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Native GUI repairs are separately checked at `44c6958` in
native-ui-acceptance.md and English lifecycle outcomes at `77e9b92` in
native-ui-lifecycle-acceptance.md. The `b59d5e9` presentation repair still requires
manual Mac unlock for German native interaction. The final docs may have a later revision; native JSON source
maps must still match every relevant source file. Both Ubuntu and macOS main CI
on `0d6728f` passed, including the shared host self-update entry. Later changes still
require corresponding current CI and relevant source-map checks.

| Criterion | Status | Current evidence / next step |
|---|---|---|
| GUI-independent application core and shared future CLI API | passed | LatestApplication depends only on LatestCore; source-boundary validator; GUI forwards ID commands and renders core state |
| Complete default workflow testing without GUI automation | passed | 35 deterministic Swift functions including four host self-update command tests, six exclusive Store workflows and malformed actual client requests; nine native opt-ins skipped by default; Xcode MCP builds current GUI without UI automation |
| Shared host self-update entry | passed | shared-self-update-acceptance.md: native SDK ownership moved from GUI into runtime; shared capability/ownership/ordinary-job/error policy, four headless tests and portable no-Sparkle-in-GUI validator |
| Scans, exact selection, preferences, migration and consent | passed | Direct core tests include supersession, ordered persistence/restart, ignored/skipped direct mutations, channel settings, stale major consent and bulk eligibility |
| Jobs, rejection, duplicate starts, cancellation, handoff and quit policy | passed | Direct core tests exercise the actual session and job transitions; actual signed provider lifecycle outcomes are recorded below |
| Actual signed Sparkle update/rejection/retry/process restart | passed | headless-native-acceptance.md: four actual native outcomes and four new process restarts; signature/architecture, exact-instance journal and unchanged controls |
| Actual targeted Homebrew update, rejection, hints, error/retry/restart | passed | headless-homebrew-acceptance.md: five actual native outcomes and five new processes; exact ownership/instance guards, signature/architecture, unchanged controls and ordinary registry/runtime |
| Actual Sparkle cancellation, HTTP failure/retry and installer handoff | passed | headless-lifecycle-acceptance.md: three actual native scenarios, controlled registered PID and three new-process restarts; original Homebrew/Sparkle suites also pass at this revision |
| Real signed native compatibility and build policy | passed | headless-compatibility-acceptance.md: four actual signed targets, exact rejection/no-job outcomes, actual lower-display/higher-build installation and four fresh process restarts on arm64 |
| Real native ignore, skip/new version and Stable/Beta persistence | passed | headless-preferences-acceptance.md: nine actual fresh processes, real signed feeds, independent JSON checks, exact-instance skip/channel policy and unchanged signed bundles; no job starts |
| Native TLS, current provider metadata and offline cache | passed | native-network-acceptance.md at ecae2d0: thirteen native processes, actual catalogue, same-certificate hostname rejection, zero-request HTTP downgrade trap, real status/JSON/valid-stream size rejection, cancellation and offline restart; independent good-cache byte/time and unchanged app-file checks |
| Real native major consent and scoped bulk installation | passed | headless-major-bulk-acceptance.md: four signed cases, four fresh restarts, real scan/download gates, zero changed-major archive requests, exactly two authorized minor jobs/downloads and unchanged excluded apps |
| Native directory/volume recovery and real superseded request | passed | headless-directory-acceptance.md: four actual cases/fresh restarts, own HFS+ volumes, production monitoring, exact persisted directory commands and drained old real HTTPS scan; no installation job |
| Actual native legacy-domain reader and JSON migration | passed | headless-migration-acceptance.md: shared reader moved from GUI to LatestCore; real CFPreferences/JSON over five processes, malformed/default and changed-source checks; only inventory/provider capabilities are scoped to the private profile |
| Native broker/XPC/Store/package scope | open | Headless native broker scopes remain; controlled authentic Store target/package/account/update is still unavailable |
| Native signed broker client/tool rejection and missing-service retry | passed | headless-broker-boundary-acceptance.md: nine actual cases, real signature/hash/symlink checks and two absent-service XPC attempts; observed callback isolation crash fixed; no root-service registration or privileged execution proof is implied |
| App Store bulk job serialization in shared core | passed | store-queue-acceptance.md: six actual production-session tests with injected exclusive runtime, ownership through verification, registered queue cancellation, failure/retry, fresh offer/ignore rejection and parallel other providers; native privileged Store bulk remains open |
| Native English lifecycle UI with close/quit guard and real installation | passed | native-ui-lifecycle-acceptance.md at 77e9b92: actual cancel, HTTP503, retry, stopped registered fixture handoff, disabled Cancel, guarded main close/quit in download/install, signed1.1 arm64 and unchanged3controls |
| Current cancellation/progress presentation and German GUI restart | not verifiable | Compiled/current CI pass; CUA reports locked Mac requiring manual owner unlock. The known idle PID95757 was safely stopped and saved private preferences restored before regression; next actual updated restart/cancellation/AX check awaits unlock |
| Keyboard, VoiceOver, large text and full EN/DE view interaction | open | native-ui-acceptance.md: actual EN/DE shortcuts, exact-instance AX, default-window 100%/160% content/control fonts and five reliable selector focus cycles pass; spoken VoiceOver, minimum/narrow windows, long notes and update/major/error/progress dialogs remain open |
| Immutable source export, fixed release metadata and archive rebuild | passed | source-release-acceptance.md at d628184: actual fresh archive/bootstrap/build, 35 regular functions, 84 invariants, 14 contracts, 85 translations and development-signed build1506 with exact source/licence checks; production artifact set remains open |
| Release signing, notarization, production self-update and artifact set | not verifiable | Owner-deferred Developer ID/notarization credentials; prepared source/artifact work remains independent |
| Current local build/regression checks | passed | 0d6728f: warnings-as-errors Debug/Release, Xcode MCP GUI build, 35 regular Swift functions plus nine explicit default native skips, 84 invariants, 14 source/feed regressions, 85 localized keys; all nine native drivers rerun and 37 current result maps match |
| Portable CI on actual Ubuntu | passed | ci-platforms.md at 4422057: actual Ubuntu 24.04 / CPython 3.14.8; thirteen Python source/history tests and all 85 translations/resource/source checks pass; further Swift candidates and compile-time blockers assessed |
| Verified implementation main CI | passed | [0d6728f / 38177801106](https://github.com/mpwg/Latest/actions/runs/38177801106): Ubuntu and macOS jobs pass; final whole-goal CI must match its final head |
| Current README/test documentation/matrix | passed | Shared-core/native instructions, boundaries, certificate lifecycle and retained evidence |

**Overall goal remains open.** No release has been published. The following
baseline matrix and subsequent older sections are retained historical evidence;
they do not supersede this current-run matrix after the application extraction.

## Historical baseline

Baseline: beta 4c1e111; local platform macOS 27.0.1 / Swift 6.4 Command Line Tools.
Verified implementation: modernization PR stack in mpwg/Latest, commit
`273136101412f767c02d40291bc08a456c2200b8`.
CI evidence: macOS 27, Xcode 27.0, Swift 6.4, runs completed on 2026-10-09
and logs/artifacts checked again on 2026-10-10.
Statuses: passed, open, not verifiable. Evidence must match current code.

| Criterion | Status | Evidence / next check |
|---|---|---|
| Audit and concept in own fork | passed | audit-2026-10-09.md, modernization.md |
| Swift 6 core and comparison contracts | passed | Compiled invariant suite, including symmetric source policies and hash/equality |
| Canonical instances / scan generations | passed | Current metadata, registered/unowned apps, removed/late results |
| HTTPS / status / bounds / cache | passed | Production client with deterministic URLProtocol transport fixtures |
| Homebrew ownership / targeted updates | passed | L03 targeted real native update and L04 native provenance-loss, changed-instance, informational catalogue and real failure/retry checks passed; scoped to isolated arm64/Tier 3 prefix |
| Bundled mas / restricted broker | open | Compiled/pinned tools, own/foreign signer checks, request and package policy passed; native privileged request/install outstanding |
| Sparkle 2.10.0 / lifecycle | passed | L05 signed installation and tamper rejection; L06 at ffb4ea0 adds real download cancellation, HTTP 503, signed retry/restart and native disabled cancellation at installer handoff; late callback/job-token contracts pass |
| SwiftUI / filtering / ignore / channels / migration | passed | L15 filtering/order, L16 instance preferences, L17 major/bulk guards and L18 normal signed startup/quit/restart migration pass with their separately documented isolation and source scopes |
| English/German string catalogues | passed | 74 keys, translated states and placeholder parity |
| Shared schemes / GitHub Actions | passed | Both linked runs on 2731361 passed bootstrap, app build, 83 compiled invariants, validation, seven Swift Testing tests, five native UI tests and debug packaging |
| Native installation / receipts / architecture | open | Actual Homebrew/Sparkle installations and L07 signed-bundle OS/architecture/version matrix pass on arm64; authentic App Store receipt/package installation still needs a controlled Store target |
| Keyboard / VoiceOver / large text | not verifiable | Native interaction |
| Release signing / notarization / self-update | not verifiable | Own Developer ID / notarization / feed |
| Appcast history and complete-feed signatures | passed | L28 seven regressions on 3ba5c3d: preserved history/notes, ordering, first/empty feed, invalid/duplicate metadata and actual complete-feed signing/tamper rejection |
| README reflects current implementation | passed | Own fork, build/verification commands, features, restrictions and release status |

Overall acceptance: open.

## Subsequent native implementation evidence

[L19](directory-acceptance.md) passed four actual native cases at
`53dc1df`: native folder selection/exclusion/removal and normal restart, populated
and empty test-volume ejection/recovery, and delayed real HTTPS scan supersession.
It fixes the observed native removal crash and warning-only monitoring gap. The
final generation guards also pass this complete native sequence.

[#51](instance-integrity-acceptance.md) at `379cacc` adds actual native rejection
of signed executable replacement and signed-code tampering despite unchanged
Info.plist and restored times. Both fail before provider work and preserve altered
target/control bytes. A valid target still installs through the actual UI.

[L18](migration-acceptance.md) at `253eafa` passes two actual signed normal-start
tests without synthetic inventory: real legacy CFPreferences values migrate,
native settings changes survive Command-Q/relaunch, changed legacy values cannot
overwrite new settings, and invalid/missing fields use defaults. The filesystem
profile and Debug-only test suite alias are explicit evidence boundaries; full
ordinary-domain/file hashes match after known discovery-metadata cleanup.

[L17](major-bulk-acceptance.md) at `11d08a6` adds four actual native cases for
major cancellation/consent, provider-declared major, changed-consent rejection
before download and two-target scoped bulk installation. Real gated scans and
downloads prove action/job protection; independent bundle/signature/architecture
checks and unchanged controls accompany the UI. Eleven Swift contracts cover
provider-major policy and compatibility with older candidate JSON.

[L16](app-preferences-acceptance.md) at `2743f68` adds two actual native tests
with real signed same-ID instances and signed HTTPS feeds: ignore/reversal,
exact-version skip/clear/restart, newer-version availability and independent
Stable/Beta channels after restart/refresh. The saved JSON is independently
checked; all fixture app bytes remain unchanged and no installation job starts.

[L15](ui-filter-sort-acceptance.md) adds a nine-record native view matrix and
fixes the Unknown Source filter. Seven native UI tests and seven Swift contracts
passed on `b61f414`; 84 invariants and warnings-as-errors Release build passed.
The read-only inventory never establishes a provider installation result.
Both filter/sort tests also pass after integration at `4e77913`, with current
Release build, 84 invariants, seven Swift contracts and seven appcast regressions.
At combined L15/L06 `271adc9`, both native filter/sort tests and all three actual
Sparkle lifecycle cases pass again; current ten Swift contracts, 84 invariants,
seven appcast regressions and warnings-as-errors Release build also pass.

[L07](sparkle-compatibility-acceptance.md) at `776c4b2` passes four actual native
cases: explicit signed x86_64 target rejected on arm64, minimum OS 99 rejected,
real incomparable signed build stays unknown, and signed 0.9.0 (2) replaces
1.0.0 (1) using the Sparkle build policy. Independent post-install signature,
bundle identity/version and lipo checks pass; control instances stay unchanged.
Evidence is explicitly scoped to the arm64 host.

[L06](sparkle-lifecycle-acceptance.md) at `ffb4ea0` records three actual native
Sparkle lifecycle tests, exact-instance/unchanged-control checks and accepted
job journals with one terminal outcome per job. Ten Swift Testing contracts
include actual adapter late-callback and handoff checks. Compatibility, Store
and production release gates remain separate.

The owner confirmed on 2026-10-10 that no controlled App Store test target is
available. L11/L12 positive installation needs an explicitly authorized Store
app with authentic receipt/account/update; L12 also needs a suitable authentic
Apple-signed fallback package. No ordinary app or fabricated receipt is
substituted. Release credentials remain deferred; overall acceptance is open.

L28 at `3ba5c3d` passes seven Python regressions including actual Swift Ed25519
signing/verification, seven Swift Testing contracts, 84 compiled invariants and
the warnings-as-errors build. [Release instructions](releasing.md) document
mandatory explicit history selection and authenticated merging. This does not
establish notarization, self-update or publication acceptance; the owner deferred
release credentials on 2026-10-10.

[L05](sparkle-native-acceptance.md) verifies three actual Sparkle UI outcomes on
`f262a29`: signed installation to 1.1.0 and two rejected modifications that
preserve the selected 1.0.0 bundle. Other same-ID instance and Homebrew control
remain byte-for-byte unchanged. Result bundles and source hashes are retained.

[L04](homebrew-native-rejection.md) adds four real native rejection/recovery
checks on `eec132b`, with no upgrade process for rejected provenance/instance/
catalogue requests and a real failed checksum upgrade followed by successful
rescan/retry. It preserves controls and records per-source hashes and xcresult
paths. Other provider, accessibility and production release gates remain open.

[L03](homebrew-native-acceptance.md) verifies `9cbec3d` on macOS 27.0.1 with
local Xcode 27.0 / Swift 6.4: one actual Homebrew-update XCUITest passed, seven
Swift tests and 84 compiled invariants passed. Real window screenshots and
observed targeted brew arguments match the installed bundle before/after.
The new optional installation test does not run against synthetic `--ui-testing`
inventory. The earlier CI section below remains explicitly scoped to 2731361;
the integrated L01/L02 main commit `a1903b8` also passed
[run 38032841390](https://github.com/mpwg/Latest/actions/runs/38032841390).

## Current CI evidence for 2731361

Both successful runs tested the exact implementation commit above:

| Run | Trigger | Retained artifact |
|---|---|---|
| [37988080394](https://github.com/mpwg/Latest/actions/runs/37988080394) | Pull request | [macOS-27-evidence / 11644028271](https://github.com/mpwg/Latest/actions/runs/37988080394/artifacts/11644028271) |
| [37988071896](https://github.com/mpwg/Latest/actions/runs/37988071896) | Push | [macOS-27-evidence / 11643464628](https://github.com/mpwg/Latest/actions/runs/37988071896/artifacts/11643464628) |

The downloaded artifacts each contain `native-tests.xcresult` and the controlled
debug `Latest.app`. The logs report **83 compiled production-code invariants**,
**74 English/German keys**, **seven Swift Testing tests** and **five native
XCUITests with zero failures**. Swift Testing runs both directly and in the
shared Xcode scheme; these are repeated runs of the same seven tests.
The UI suite runs real macOS views with `--ui-testing` and an isolated debug
inventory. Its exact behaviours and remaining limits are listed in
[test coverage](test-coverage.md#native-ui-evidence-for-2731361).

CI packages an **ad-hoc debug bundle**. It does not prove production signing,
privileged broker registration or any real provider installation.

## Earlier local evidence and its limits

The following observations were recorded during the modernization and are
retained as historical local evidence, not fresh production acceptance:

- `swift build -Xswiftc -warnings-as-errors`: passed locally. CLT linker reports
  missing optional Developer framework search directories; no Swift warning or
  source error was suppressed.
- `LATEST_TEST_APP_BUNDLE=<own Developer-signed fixture> .build/debug/LatestVerification`:
  **86 passed**: 83 core/process/adapter/transport checks plus three own signature
  and sealed tool-digest checks.
- `python3 scripts/validate.py`: **74 English/German keys passed**, source boundary,
  project plist and shared scheme syntax passed.
- `package_app.py`: own Developer-signed bundle, hardened runtime, matching actual
  TeamIdentifier, deep/strict code-signature verification passed. No service was
  registered and no installed application was changed.
- Controlled native launch: one own-fork process and a **1000 × 702** main window
  observed through CoreGraphics; isolated `.build/ui-smoke/preferences.json`.
  This proves startup, not VoiceOver or full interaction.

## L01 documentation acceptance (#6)

| Criterion | Status | Evidence |
|---|---|---|
| Exact implementation commit, both successful runs and xcresult links | passed | Commit and artifact table above; both artifacts downloaded and their result bundles checked on 2026-10-10 |
| Five native UI behaviours listed with separate remaining gates | passed | Native UI table in test-coverage.md; installation and accessibility rows remain open/not verifiable |
| Obsolete pending-CI claims removed; README remains consistent | passed | Shared-scheme row above and updated README release status |
| Evidence has environment, revision and observed result | passed | CI logs, artifact metadata and local documentation checks; no runtime code changed in L01 |

Developer ID/notarization and a real signed self-update remain unavailable in
this environment. Real App Store receipts/package compatibility and controlled
Sparkle/Homebrew updates are not inferred from fixture successes.
