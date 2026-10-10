# Native normal-start migration — L18 (#23)

Observed on 2026-10-10 at `253eafa`, macOS 27.0.1 (26A434), Xcode 27.0
(27A266a), Swift 6.4, arm64. The actual client and runner use the own Apple
Development team `PZV43D6HWT`. These tests launch the signed native application
through its normal startup and settings paths, then quit through Command-Q.

## Reproduce and isolation

With the signed [native fixture prerequisites](native-fixtures.md), run:

```sh
python3 scripts/native_migration.py all
```

`valid` checks migration, native settings changes, normal quit/restart and a
changed legacy source. `malformed` checks invalid/missing legacy fields and
another normal quit/restart. Each case creates a fresh filesystem profile and
a unique real CFPreferences domain, writes the actual legacy keys with `defaults
import`, and deletes only that generated domain afterwards.

No `--ui-testing`, synthetic inventory or `--native-install-test-directory` is
used. `CFFIXED_USER_HOME` redirects the normal Application Support path. macOS's
preferences daemon remains user-scoped despite this environment variable, so
the Debug-only `--native-migration-test-domain` aliases the legacy domain to a
name constrained to `io.github.mpwg.Latest.NativeMigration.*`. The production
reader, value conversion and PreferencesStore are unchanged. Release builds
always read the actual `com.max-langer.Latest` domain; the alias is not available
there. This is a controlled data-source boundary, not an injected preference result.

Normal discovery still reads real applications. On this host it checks an
installed legacy Latest and Sparkle updates that app's `SULastCheckTime` runtime
metadata. The driver verifies that this is the sole domain delta before restoring
the captured prior domain. It refuses to overwrite other changed settings.
The final full domain hash and ordinary own-fork preferences-file hash must match
their initial values. No installed app is updated or helper registered.

## Criteria matrix

| Criterion | Status | Actual observed native result |
|---|---|---|
| Legacy values migrate on first normal signed startup | passed | Real CFPreferences directory/ignore/visibility values become the normal profile's JSON; native Settings switches show false/true/false; duplicate absolute directory is included once and a relative path excluded |
| A later launch does not repeat migration | passed | Change new settings through native switches, change the actual legacy source to conflicting values, quit normally and relaunch; new settings and original migrated directory/ignore state remain |
| New settings survive normal quit/restart | passed | Command-Q reaches notRunning; relaunch still shows true/false/true visibility and source sorting; independently verified JSON matches |
| Damaged and missing legacy fields behave predictably | passed | Invalid array/boolean values and relative directory use documented defaults; native switches and saved JSON match on first launch and after normal quit/restart |
| Existing user state is preserved | passed | Separate profile/domain, generated suite removed; known discovery timestamp restored only after verifying no other delta; final complete legacy-domain and ordinary preferences-file hashes match |
| Revision, environment, actual flow and README | passed | README links reproduction; retained result.json, before/after hashes and unique native xcresults identify the actual normal launch mode, source hashes, signing team and each UI/persistence checkpoint |

Both actual XCUITests passed with zero failures. Evidence is retained under
`.build/native-install-tests/evidence/l18/{case}/{unique-id}/`: native log,
unique `native-tests-*.xcresult`, `result.json`, profile files and domain snapshots.
The latter are private local evidence under the owner-only fixture root, not
repository artifacts. The test asserts that the app really uses its normal
isolated Application Support location before evaluating migration results.

Supporting current checks: warnings-as-errors Release build, 84 compiled
invariants, eleven Swift Testing contracts, seven appcast regressions and 74
English/German keys. This establishes migration and persistence on the signed
normal business path with the explicit test-domain isolation above. Privileged
Store installation, accessibility and production release remain separate gates.
