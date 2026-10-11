# Modernization for macOS 27

The public mpwg/Latest fork uses a Swift 6 core, SwiftUI and separate adapters
for Sparkle 2.10.0, mas v7.0.0 and locally managed Homebrew casks. Bundle IDs
start with io.github.mpwg.Latest. Preserve copyright and GPL notices. Repository
prose, comments, commits and PRs are English; UI translations remain localized.

## Layers

- LatestCore: immutable Sendable snapshots, structural versions, provenance,
  decisions, jobs, generations, bounded networking and atomic cache.
- LatestApplication: GUI-independent observable session, scans, selection, preferences,
  major consent, update jobs and front-end effects; depends only on LatestCore.
- LatestPlatform: canonical inventory, subprocesses, metadata, main-actor
  Sparkle adapter and broker client.
- LatestApp: SwiftUI/AppKit rendering and native UI effects only, forwarding shared
  session commands; no private Apple frameworks. A future CLI uses the same core.

Automated application tests run without GUI automation. Native installer tests
drive the same application/runtime APIs with controlled apps. Manual UI and
accessibility acceptance stay distinct. Manage the Xcode project with Xcode MCP;
do not regenerate it with Python. See headless-architecture.md.
- LatestBroker: SMAppService daemon with mutual signature validation, accepting
  only one verified numeric App Store update request for bundled mas.

The broker accepts no executable, package or receipt paths. Stage and verify
its pinned tool in root-owned storage; authenticate both peers and serialize
jobs. Derive UID/GID from the XPC peer, use an allowlisted environment, and bound
runtime/output. mas addresses IDs rather than exact instances: duplicates,
nonstandard locations and iOS/iPadOS apps fall back to App Store. Do not reproduce
the beta package/receipt installer.

## Behaviour

Installation requires fresh provenance and unambiguous identity. Receipts,
local Homebrew installations and verified Sparkle feeds are separate evidence.
Names never authorize installation. Check architecture, minimum OS and channel.
New scans supersede older generations. Read installed apps after updates; late
callbacks cannot change a newer scan. Missing/incomparable versions are unknown.
Only valid caches are stored atomically. Require HTTPS, HTTP status validation
and size limits. Release notes render as text without scripts or embedded remote
resources. External links open in the browser.

UI: search, source filters, stable sorting, configurable directories, skip one
version, ignore an app, channel selection, major-upgrade confirmation, actionable
errors and local diagnostics. Migrate previous preferences once. Installation is
user-initiated; background operation is deferred.

## Release and acceptance

Require Xcode 27, Swift 6 and macOS 27. Signed/notarized archives, an own EdDSA
key, own feed and matching source revision form a release. Never commit private
keys. Publish only through the own fork. Tests do not silently publish releases
or update user applications. acceptance.md records current evidence. Open native
installation, VoiceOver, signing or notarization criteria prevent completion.
