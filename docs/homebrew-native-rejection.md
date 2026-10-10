# Native Homebrew rejection and recovery — L04 (#9)

Environment: macOS 27.0.1, Xcode 27.0 (27A266a), Swift 6.4, arm64, own
Development-signed client/runner (`PZV43D6HWT`), isolated real Homebrew prefix.
The tested implementation is `eec132b`; each result also records hashes of the
application model, catalogue adapter, process environment and native test source.

## Reproduce

Use the [prepared native fixtures](native-fixtures.md), running localhost HTTPS
server and explicitly approved localhost trust, then run:

```sh
python3 scripts/native_homebrew_rejection.py all
```

Individual cases are `loss`, `swap`, `catalogue` and `retry`. Each recreates the
real managed 1.0.0 baseline through brew and exposes 1.1.0 in its isolated tap.
Unregistered fixture copies are preserved under `evidence/l04/reset-backups/`
before re-registration. Bundle-swap backups have unique names and remain under
the generated root; no production app is removed or used as test material.

The test driver waits for native XCTest phase markers, changes only the real
disposable app/registration/cask and releases the test through a file marker.
It observes actual upgrade process IDs/argv, checks installed metadata and byte
digests of unrelated control apps, and retains a unique xcresult for each case.
No fake brew executable, fabricated Caskroom registration or forced success is
used. Without the explicit fixture environment, these tests are skipped.

## Criteria matrix

| Criterion | Status | Native evidence |
|---|---|---|
| Lost provenance prevents update | passed | Real brew uninstall after native selection; restore the same signed app as unmanaged; explicit rescan disables Update; zero upgrade processes |
| Replaced selected bundle prevents update | passed | Replace selected 1.0.0 bundle with signed 1.1.0 before clicking Update; production fingerprint guard shows the changed-app error; zero upgrade processes |
| Equal name/catalogue hint cannot authorize installation | passed | Real HTTPS catalogue names the unmanaged copy and offers 2.0.0; native Catalogue Hint filter selects its exact path; informational reason visible and Update disabled; zero upgrade processes |
| A real failed update is not success | passed | Invalid cask checksum makes actual brew upgrade fail; native error is visible and selected installed version remains 1.0.0 |
| Scan and retry remain possible | passed | Restore valid checksum, dismiss the native dialog, rescan and click Update again; second actual upgrade reaches verified 1.1.0 / Up to Date |
| Controls, current evidence and documentation | passed | Unmanaged/Sparkle control bytes and host cask list unchanged; result.json has source hashes, process evidence and xcresult path; README updated |

The bundle-swap case explicitly holds **automatic** inventory monitoring through
a debug-only native-test flag. This makes the stale-selection interval
deterministic. Manual refresh and the actual production installation-time
freshness/provenance checks remain active; normal and Release app behaviour
does not use this flag.

The catalogue case injects only a controlled HTTPS metadata endpoint into the
real read-only CatalogueProvider. Catalogue candidates always retain
`authoritative: false` and `action: .none`. No catalogue fixture can turn into an
installation source.

## Supporting changes and limits

- Native dialog selectors are bounded to window controls to exclude duplicate
  Touch Bar buttons. These are actual macOS interactions, not browser emulation.
- Configured absolute Homebrew cache/log/temp directories are kept in ordinary
  child environments, so fixture writes stay in the isolated root. Root broker
  environments remain separately constructed.
- `evidence/l04/<case>/result.json` and `native-tests-*.xcresult` retain every
  observed result. The failure/retry case records baseline 1.0.0 after failure
  and distinct real upgrade process IDs for both attempts.

These checks cover one arm64 Mac and a nonstandard Tier 3 prefix. They do not
establish arbitrary casks, x86_64, privileged installation, App Store, Sparkle
installation or production release acceptance. Overall acceptance remains open.
