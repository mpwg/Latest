# Latest — mpwg fork

A native macOS 27+ application that inventories installed apps, reports their
update provenance and performs user-initiated updates through Sparkle,
Homebrew or a restricted App Store helper. The modernization starts from
upstream 0.12-beta2. This fork is an independent project; releases and support
belong to [mpwg/Latest](https://github.com/mpwg/Latest).

The [shared application core](docs/headless-architecture.md) owns discovery,
selection, preferences, consent and update jobs independently of the GUI.
The native interface renders shared state and forwards commands; a later CLI
will use the same session and platform runtime. Automated application tests and
CI run without GUI automation. Xcode project changes use Xcode MCP.

The [direct native Sparkle suite](docs/headless-native-acceptance.md) now checks
actual signed installation, archive/signature rejection and successful retry
through that same core, without GUI automation. A separate process restart
checks every outcome; other controlled app instances retain identical bytes.
Run `python3 scripts/native_headless_sparkle.py all` after preparing the fixtures
and compiling the opt-in Swift test. Its fixture certificate is reused until
natural expiry, without changing trust between test runs.

The [direct native Homebrew suite](docs/headless-homebrew-acceptance.md) checks
real targeted upgrade, lost ownership with unchanged app identity, changed
selected instance, nonauthorizing HTTPS catalogue hints and real checksum
failure/retry. Each case restarts in a new process and preserves other apps and
the normal Homebrew registry/runtime. Run
`python3 scripts/native_headless_homebrew.py all` after compiling the opt-in test.
Structured subprocess output remains separate from bounded diagnostics.

The [L06 native Sparkle lifecycle suite](docs/sparkle-lifecycle-acceptance.md)
checks actual download cancellation, failure, installer handoff and successful
retry/restart. The adapter rejects cancellation from extraction onward and
ignores late completion callbacks. Positive App Store installation still needs
a controlled Store target; production signing, notarization and self-update
require the deferred release credentials.

The [L07 native compatibility matrix](docs/sparkle-compatibility-acceptance.md)
also checks explicit architecture/OS rejection and real signed bundle versions.
It verifies the actual installed executable on an arm64 Mac; no Intel-host
acceptance is inferred.

The [L16 native preferences suite](docs/app-preferences-acceptance.md) verifies
ignore/reversal, version skipping and clearing, later-version availability and
Stable/Beta persistence for the selected canonical instance. It uses actual
signed bundles and production provider checks, preserving every fixture bundle.

The [L17 native major/bulk suite](docs/major-bulk-acceptance.md) verifies explicit
major consent, provider-declared major updates and rejection of a newly changed
consent requirement. Bulk updates include only available eligible minor targets.
Scan-time and repeated starts are guarded, and selected version accessibility
values stay current after installation.

The [native instance-integrity checks](docs/instance-integrity-acceptance.md)
reject executable replacement and signature tampering despite preserved metadata
and times. Installation compares filesystem, architecture, receipt and signing
identity, validates present signatures and rechecks identity before provider work.

The [L18 normal-start migration suite](docs/migration-acceptance.md) verifies
legacy directories/ignore/visibility migration once, native settings changes,
normal quit/restart and malformed defaults on a signed client. Separate profile
and test-domain isolation preserve existing user state.

The [L19 native directory suite](docs/directory-acceptance.md) checks the real
folder picker, exclusions, removal and persistence across normal quit/restart.
Actual populated and empty test volumes verify automatic warning/recovery; a
held HTTPS scan cannot restore an app after its directory is removed. Native
acceptance found and fixed a directory-removal exclusivity crash.

## Build and verify

Use Xcode 27 / Swift 6.4 and macOS 27 or newer:

```sh
python3 scripts/bootstrap.py
swift build
.build/debug/LatestVerification
python3 scripts/validate.py
swift test --build-system native --enable-swift-testing --disable-xctest
```

The compiled verification executable also works with the macOS 27 Command
Line Tools. Swift Testing and XCUITest require full Xcode. Open the shared
Latest.xcodeproj scheme for native builds. Run only LatestCoreTests through
Xcode MCP for headless tests; historical XCUITests are optional reproduction
material. Dependencies are pinned in
Config/dependencies.json and mas's committed upstream Package.resolved;
bootstrap applies the reviewed SDK and package-verification patches.

Create an app bundle with your Apple Development identity and team:

```sh
python3 scripts/package_app.py --identity YOUR_SIGNING_IDENTITY --team YOUR_TEAM_ID
```

A bundle signed ad hoc is only a packaging artifact: it cannot use the privileged
broker and cannot load non-platform frameworks under production library
validation. Developer-signed bundles keep hardened runtime and library validation.
No packaging command registers a helper or modifies installed applications.

For controlled installation acceptance, use the
[disposable native fixtures](docs/native-fixtures.md). They provide two own
signed app versions, separate preferences, a local HTTPS feed and a real cask
inside an isolated Homebrew prefix, with explicit cleanup instructions. Fixture
preparation is separate from successfully updating an app through Latest.
The [L03 native Homebrew acceptance](docs/homebrew-native-acceptance.md) now
passes through the real UI on an own signed client: it updates only the managed
fixture from 1.0.0 to 1.1.0, verifies the installed bundle and preserves the
equal-name unmanaged copy. Reproduction requires full Xcode 27 and the explicitly
prepared fixture environment. Other installation and production gates remain open.
The [L04 native rejection suite](docs/homebrew-native-rejection.md) also verifies
lost registration, a replaced selected bundle, non-authorizing catalogue hints
and an actual failed update followed by successful rescan/retry. Run it with
`python3 scripts/native_homebrew_rejection.py all` against the disposable fixtures.
The [L05 native Sparkle acceptance](docs/sparkle-native-acceptance.md) verifies
an actual signed 1.0.0-to-1.1.0 update of the selected instance and rejection of
both a modified archive and an invalid enclosure signature. The other instance
and provider fixture remain unchanged. Reproduce with
`python3 scripts/native_sparkle_acceptance.py all` against the same environment.

## Features and boundaries

- Native SwiftUI inventory, search, source filtering, stable name/path sorting,
  source sorting, larger text, plain-text release notes and local diagnostics.
- Explicit unknown, incompatible, up-to-date, available, ignored and skipped states.
- App-level stable/beta channels; major upgrades require confirmation and are
  excluded from bulk updates.
- Configurable scan directories, including disabling standard application folders.
- One-time migration of old location, ignored-app and visibility preferences.
- Installed Homebrew casks require a canonical local registration. Catalogue
  hints are optional and never authorize an installation. Homebrew is optional.
- Sparkle 2.10 uses public APIs and the exact selected bundle. Explicitly
  incompatible architecture URLs are rejected. Dynamic feeds without verifiable
  metadata need the application's own updater.
- App Store updates use pinned mas v7.0.0 behind a mutually authenticated broker.
  Duplicate instances, wrapped iOS apps and nonstandard locations open App Store.
  Package fallback requires authenticated Apple signing, the selected bundle and
  a restricted payload; packages with scripts or unverifiable metadata are rejected.
- HTTPS-only bounded responses, last-known-good cache with stale state, scan
  generations and one terminal update outcome.

The helper is enabled explicitly in Settings and approved in System Settings.
Preflight can be cancelled; once an installer is handed off, the bounded job
finishes safely even if the client disconnects. Closing/quitting while updates
run is prevented by the application. Success requires checking the installed
bundle again, not just a successful process exit.

English is the repository and source language. The new UI supports English and
German; legacy translation resources remain as references for future migrations.

## Release status

The [L15 native UI matrix](docs/ui-filter-sort-acceptance.md) verifies every source
filter, state visibility, stable name/path/source ordering and selected-instance
retention through repeated scans. Its read-only inventory establishes native
view behaviour, with provider installation and accessibility covered separately.

**The modernization is not fully accepted for production.** See
[acceptance](docs/acceptance.md) for current evidence and remaining native
installation, accessibility, signing, notarization and self-update gates.
The historical implementation at `2731361` passed both Xcode 27 CI runs,
including seven Swift Testing tests and five native UI tests. The
[test coverage](docs/test-coverage.md#native-ui-evidence-for-2731361) lists exactly
what those isolated UI fixtures establish. Real provider installations,
privileged broker behaviour and full accessibility still need separate evidence.
No release has been published and no user application was updated during tests.

The fork's public update key and feed are in Config/updates.json. The private key
is excluded under .release/ and must be backed up securely. Release packaging
requires your own Developer ID, notarization credentials and the matching
Ed25519 seed. Never commit or print a private signing key.

Release preparation builds one clean immutable Git export and records source,
archive, feed, dependency/patch and toolchain metadata in hash manifests.
`python3 scripts/release.py --version 1.0.0 --prepare-source-only` prepares the
source archive independently of signing credentials. The
[actual source rebuild](docs/source-release-acceptance.md) passes with pinned
dependencies, explicit metadata and existing development signing. The signed production path
still requires Developer ID/notarization and current native acceptance.

Signed release preparation requires either `--first-release` or `--existing-feed`.
Existing feed signatures and metadata are checked before notarization, historical
entries are retained and the complete result is signed again. Run
`python3 -m unittest discover -s Tests/ReleaseTests -v` after `swift build` for
the independent source-export, metadata-binding and feed-history/signing checks. See [release procedure](docs/releasing.md).

See [architecture](docs/modernization.md), [beta audit](docs/audit-2026-10-09.md),
[test coverage](docs/test-coverage.md) and [security boundary](docs/security-boundary.md).

## Upstream and licence

Based on [Max Langer's Latest](https://github.com/mangerlahn/Latest).
Preserve its copyright and [GPL-3.0 licence](LICENSE.md).
Sparkle and mas retain their respective upstream licences; packaging includes
the application's licence and dependency notices.
