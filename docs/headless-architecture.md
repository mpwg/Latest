# Shared application core and headless tests

The GUI and a future CLI use `LatestApplication.ApplicationSession` and the
same `LatestPlatform.LiveApplicationRuntime`. The CLI itself is deferred.
`LatestApplication` depends only on `LatestCore`, Foundation and Observation;
it has no AppKit, SwiftUI, Sparkle or platform-adapter dependency. MainActor
serializes observable application state; it does not require a window,
NSApplication, GUI event automation or a running application bundle.

## Responsibilities

| Layer | Responsibility |
|---|---|
| LatestCore | Immutable app identity, versions, provenance, resolution, filtering, compatibility, persistence and job transitions |
| LatestApplication | Scan ownership, selected instance, notes, preferences, consent, update eligibility, jobs, cancellation, errors and quit eligibility |
| LatestPlatform | Inventory/signatures, HTTP/provider checks, exact-instance preflight, restricted broker, installation and installed-result verification |
| LatestApp | Native views, icons, menus, windows, folder picker, browser/Finder effects and localization |

Commands use canonical `AppInstanceID` values. Front ends cannot mutate authoritative
rows, provider records, job events or scan state. Update and cancellation button
eligibility comes from `canUpdate` / `canCancel`; closing/quit eligibility comes
from `canQuit`. Major confirmation checks the exact candidate again. Preferences
save in mutation order. Changing directories/channels refreshes from the core;
selection changes fetch/sanitize release notes from the core. Direct ignored/
skipped preference changes also refresh eligibility without any view hook. A requested external
updater is an `externalURL` effect consumed by the front end, without starting
an installation job. Broker registration returns approval state without opening
System Settings from the shared runtime.

Construct a session with a runtime, preferences URL, diagnostics URL and optional
legacy values. `start()` loads/migrates persisted settings and starts discovery.
After `refresh()`, await `waitForScan()` to observe the completed generation;
after update commands, await `waitForUpdates()`. Await `flushPreferences()` before
ending a short-lived CLI session. Monitoring is optional and can be stopped.
Native runtime installation retains signature/fingerprint preflight, provider
freshness checks, bounded subprocesses and installed-version/architecture checks.

The GUI composition root supplies paths and native adapters. Its Debug-only,
read-only inventory fixture support preserves reproduction of historical view
checks; it does not authorize or establish native provider installation.

## Automated verification without GUI automation

```sh
swift build -Xswiftc -warnings-as-errors
.build/debug/LatestVerification
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/validate.py
python3 -m unittest discover -s Tests/ReleaseTests -v
swift build -c release -Xswiftc -warnings-as-errors
```

`ApplicationTests` drives the actual production session with an injected runtime.
It covers exact-instance selection/update, filtering, sanitized notes, separated
real subprocess stdout/stderr and aggregate diagnostics bounds, major
cancellation/consent/stale consent, bulk eligibility, changed-instance preflight
rejection, duplicate starts, failure/retry, callbacks from an obsolete job during
a retry, download cancellation, installer handoff/quit protection, independent
installed-result failure, superseded scans, migration, serialized settings and
restart, and external-updater effects. Gates control races; no GUI, clicks,
keyboard synthesis, fixed sleeps or ordinary user-app update is involved.

CI runs these tests and the existing invariant/feed suites, then builds/packages
the native GUI wrapper. It does not execute XCUITest. Historical XCUITest sources
and fixture drivers remain optional reproduction material; they are not a
requirement for automated application correctness. Xcode MCP can run only the
`LatestCoreTests` target; do not use RunAllTests while the historical UI target
is still included in the shared scheme.

Manage the existing Xcode project through Xcode MCP. The Python project generator
has been removed. The existing platform product links the new application module
transitively; no external project regeneration is needed.

## Evidence and limits

Current checked revision/results are recorded in acceptance.md. Local evidence
lives under `.build/headless-*`; Xcode MCP also returns its unit-test xcresult.
A successful headless test of an injected installer establishes workflow policy,
not a real provider installation. [Five actual Homebrew outcomes](headless-homebrew-acceptance.md) and
[four actual signed Sparkle outcomes](headless-native-acceptance.md) now pass
through the shared runtime, including a separate process restart after each and
retry without resetting the rejected bundle. The [three real lifecycle gates](headless-lifecycle-acceptance.md) also pass
without GUI automation.
The [four signed compatibility cases](headless-compatibility-acceptance.md)
also run through the production session with separate process restarts.
The [native preferences scenarios](headless-preferences-acceptance.md) exercise
ignore/skip/channel persistence through nine fresh processes and real signed
feeds, with independently checked JSON and unchanged apps.
Remaining native provider/platform
scopes must be rerun through the shared runtime after this extraction.
Manual keyboard, VoiceOver, large-text and English/German view acceptance remain
separate release criteria. App Store receipts/account/update and production
Developer ID/notarization/self-update prerequisites remain open. No release
publication is authorized by this architecture change.
