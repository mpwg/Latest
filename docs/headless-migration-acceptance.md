# Actual native legacy preferences and JSON migration

Observed again on 2026-10-11 at `e75ed99`, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. The production `LegacyPreferences.read` now lives in
LatestCore; the GUI composition root calls the same reader available to a
future CLI. Reading/type conversion no longer needs duplication in a front end.

## Reproduce

With the controlled signed fixtures prepared:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_migration.py all
```

The driver creates a unique actual macOS CFPreferences domain restricted to
`io.github.mpwg.Latest.NativeMigration.Headless.*`, imports real plist values with
`defaults`, and starts five separate Swift processes. Every process uses the
shared production reader, ApplicationSession and PreferencesStore against a
private profile's Application Support JSON path. The driver independently reads
that JSON after each process. Only the generated preferences domain is deleted
afterwards; certificates/trust and ordinary preference domains are unchanged.

| Criterion | Status | Actual observed result |
|---|---|---|
| Native first migration | passed | Real duplicate absolute directory, ignored IDs and visibility keys migrate; absolute directory is included once, relative directory excluded and false/true/false visibility persisted |
| Actual changes persist | passed | Next process loads migrated values, sets true/false/true visibility, source sorting and fontScale 1.4 through the shared session, then flushes the real JSON |
| Changed legacy source cannot overwrite new state | passed | Driver imports conflicting real legacy values; fresh process confirms those values were read but existing JSON keeps original migrated directory/ignored IDs and the edited settings |
| Malformed/missing native values | passed | Actual invalid array/boolean fields and relative directory yield documented defaults; two fresh processes and independently read JSON agree |
| Native inventory and signed control preservation | passed | A real signed bundle in the migrated private directory is discovered; all controlled bundle bytes remain identical, signature/arm64 verification passes, no installation job starts |
| Ordinary user preferences preserved | passed | Complete ordinary legacy-domain and own-fork preferences-file hashes match before/after; no timestamp or settings restoration is performed |

Isolation boundary: the injected inventory capability uses the actual native
AppInventory only inside the private profile; provider/network/installation
capabilities do not execute. This prevents discovery of ordinary apps from
mutating Sparkle runtime metadata. CFPreferences reading, type conversion,
migration, application preferences and native JSON persistence are real
production paths. This establishes those subsystems; it does not establish
normal GUI launch, provider installation, native settings controls or layout.

Private evidence lives at
`.build/native-install-tests/evidence/headless-migration/{case}/{unique-id}/`:
per-process logs, real legacy plists, profile JSON and `result.json`. Results
record exact revision/source hashes, environment, isolated domain/profile,
commands/PIDs, each independently read persisted state and ordinary before/after
hashes. GUI automation, App Store receipts/packages and production release
credentials are not used.
