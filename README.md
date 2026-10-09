# Latest — mpwg fork

A native macOS 27+ application that inventories installed apps, reports their
update provenance and performs user-initiated updates through Sparkle,
Homebrew or a restricted App Store helper. The modernization starts from
upstream 0.12-beta2. This fork is an independent project; releases and support
belong to [mpwg/Latest](https://github.com/mpwg/Latest).

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
Latest.xcodeproj scheme for native tests. Dependencies are pinned in
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

**The modernization is not fully accepted for production.** See
[acceptance](docs/acceptance.md) for current evidence and remaining native
installation, accessibility, signing, notarization and self-update gates.
No release has been published and no user application was updated during tests.

The fork's public update key and feed are in Config/updates.json. The private key
is excluded under .release/ and must be backed up securely. Release packaging
requires your own Developer ID, notarization credentials and the matching
Ed25519 seed. Never commit or print a private signing key.

See [architecture](docs/modernization.md), [beta audit](docs/audit-2026-10-09.md),
[test coverage](docs/test-coverage.md) and [security boundary](docs/security-boundary.md).

## Upstream and licence

Based on [Max Langer's Latest](https://github.com/mangerlahn/Latest).
Preserve its copyright and [GPL-3.0 licence](LICENSE.md).
Sparkle and mas retain their respective upstream licences; packaging includes
the application's licence and dependency notices.
