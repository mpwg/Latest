# Disposable native installation fixtures

The L02 environment prepares real Apple-signed app bundles and one real cask in
a separate Homebrew prefix. It is preparation for native acceptance, not proof
that Latest's installers have passed L03–L14.

Use macOS 27 and Swift 6.4. Full Xcode 27 is required for Swift Testing/XCUITest;
the app fixture itself also compiles with the macOS 27 Command Line Tools.
The Xcode 27 workflow compiles the fixture with warnings as errors. Local
installation fixtures require an own Apple Development or Developer ID identity.

## Prepare and inspect

```sh
python3 scripts/native_fixtures.py prepare --identity YOUR_SIGNING_IDENTITY --homebrew
python3 scripts/native_fixtures.py verify
```

Preparation refuses an existing fixture root and ad-hoc signing. Everything
generated lives under `.build/native-install-tests/`, with an owner-only root:

| Content | Purpose |
|---|---|
| `versions/sparkle/{1.0.0,1.1.0}/Latest Sparkle Fixture.app` | Two signed Sparkle host versions, builds 1 and 2 |
| `versions/homebrew/{1.0.0,1.1.0}/Latest Homebrew Fixture.app` | Two signed cask versions |
| `applications/` | Disposable Sparkle baseline and Homebrew-managed baseline |
| `preferences/` | Separate preferences for controlled Latest launches |
| `homebrew/` | Isolated real brew repository, tap and Caskroom |
| `user-config/` | Isolated XDG Homebrew trust/configuration, including explicit trust for only the disposable cask |
| `web/` | Signed appcast and four signed-app ZIP archives only |
| `private/` | Independent fixture-only Ed25519 key and local TLS key |
| `manifest.json` | Source revision/hash, versions, IDs, paths, architecture, signing team/authority and archive digests |

The fixture IDs are `io.github.mpwg.Latest.NativeFixture.Sparkle` and
`io.github.mpwg.Latest.NativeFixture.Homebrew`. A native app executable can print
its actual bundle metadata with `--fixture-metadata`.

Homebrew is cloned locally from the installed brew repository and may reuse its
portable Ruby runtime by copying it into the isolated prefix. It never symlinks
the vendor directory to the host, so automatic Ruby provisioning stays isolated.
The fixture prefix, tap, Caskroom, app destination, cache,
logs, XDG trust/configuration and temporary files remain under the generated root. The host's installed
casks and its prefix are not used as installation targets. This nonstandard
prefix is a Homebrew Tier 3 test configuration; results must name that limit.
The cask downloads the prepared local ZIP with its exact SHA-256. No mock brew
process or fabricated registration is involved.

To make only the disposable cask's next version available for L03:

```sh
python3 scripts/native_fixtures.py set-cask-version 1.1.0
```

This changes the test tap, not the installed baseline. Let the real provider
perform the subsequent update in its separately recorded acceptance test.
The [L03 native Homebrew test](homebrew-native-acceptance.md) exercises the actual
application through a locally signed XCUITest runner with full Xcode 27.

## Controlled HTTPS

```sh
python3 scripts/native_fixtures.py serve
```

The server binds only `127.0.0.1:8443` and serves `web/`. The seven-day TLS
certificate has localhost/127.0.0.1 subject names. Reuse this certificate and
its approved user-domain trust throughout its validity; do not rotate or remove
it between runs. The owner explicitly requested this lifecycle on 2026-10-11. Before adding user trust,
native URLSession rejects it with `NSURLErrorServerCertificateUntrusted` (-1202).
An explicit-certificate transport check does not change system trust:

```sh
curl --fail --cacert .build/native-install-tests/tls.crt https://localhost:8443/appcast.xml
```

For actual Sparkle acceptance, **explicitly approve the temporary user-keychain
change first**, then run:

```sh
python3 scripts/native_fixtures.py trust-localhost
```

This command adds only the generated certificate to the user's default keychain
with an SSL policy constrained to `localhost`. It records that keychain in the
manifest. The owner approved this temporary trust for the controlled acceptance
tests on 2026-10-10. The current certificate expires on 2026-10-17 at 06:45:50 UTC (08:45:50 in
Vienna). Native `security verify-cert` succeeds now and returns
`CSSMERR_TP_CERT_EXPIRED` for 06:45:51 UTC that day. Leave it configured until
expiry, as requested on 2026-10-11. For an explicitly requested cleanup only:

```sh
python3 scripts/native_fixtures.py untrust-localhost
```

The independent fixture key signs the ZIP enclosure and entire appcast. It does
not reuse the production release seed. Private keys are never served, printed
or included in repository commits.

## Reset and reproduce

Stop the foreground HTTPS server with Ctrl-C before resetting the environment.
Then run:

```sh
python3 scripts/native_fixtures.py cleanup
python3 scripts/native_fixtures.py prepare --identity YOUR_SIGNING_IDENTITY --homebrew
python3 scripts/native_fixtures.py verify
```

Cleanup verifies the generated manifest/root, uninstalls only the disposable
cask from the isolated prefix, removes its recorded certificate trust and
certificate, and deletes only the generated root. A new preparation uses new
fixture keys/certificates and restores both baseline apps to 1.0.0.

## App Store prerequisites

App Store receipts and Apple-signed packages are not fabricated. L11–L14 need
a dedicated App Store installation with a valid receipt and store account, a
real available update, the signed own-fork broker and its explicit System
Settings approval. L12 additionally needs an authentic suitable Apple-signed
fallback package. If those prerequisites are absent, the corresponding
installation criterion remains not verifiable. Ordinary user apps are not
substituted as disposable fixtures.

## L02 acceptance (#7)

Observed locally on 2026-10-10, macOS 27.0.1 / Swift 6.4 CLT, arm64. The fixture
source is committed in `2506edf`; `manifest.json` records its SHA-256 and the
checkout revision used for each preparation. Actual signing TeamIdentifier:
`PZV43D6HWT` (read from codesign, not inferred from the certificate display name).

| Criterion | Status | Evidence |
|---|---|---|
| Baseline/target versions, IDs, paths, architectures and signers | passed | Four manifest entries; deep/strict signature checks and native executable metadata match |
| Two signed Sparkle versions and a test-only managed Homebrew app | passed | Versions 1.0.0/1.1.0 generated for both sources; isolated brew reports exactly one installed cask at baseline 1.0.0 |
| App Store prerequisites documented separately | passed | Explicit prerequisites above; no synthetic receipt/package claim |
| Reproducible setup and cleanup without production app targets | passed | Full cleanup/reprepare completed; normal brew cask listing identical before/after; ad-hoc preparation refused before creating files |
| Controlled native HTTPS | passed | URLSession rejected untrusted TLS (-1202), then returned HTTP 200 for the appcast after approved localhost trust; private-key path returned HTTP 404 |
| README and current evidence | passed | README links preparation/cleanup instructions; repository validation and current fixture verification passed |

These checks do not yet install an update through Latest, register a privileged
broker or establish App Store, VoiceOver, Developer ID or notarization acceptance.
