# Direct native Sparkle compatibility without GUI automation

Observed again on 2026-10-11 at `1dd0240`, macOS 27.0.1 / Xcode 27.0 / Swift 6.4,
arm64. The actual production ApplicationSession and LiveApplicationRuntime
discover signed bundles and check real signed HTTPS appcasts. No injected
provider result, installer or GUI automation participates.

## Reproduce

Prepare the disposable [native fixtures](native-fixtures.md), retain the already
approved localhost certificate/trust, and run its HTTPS server. Compile the
opt-in Swift test before using `--skip-build`:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_compatibility.py all
```

The driver reuses the existing Apple Development signer and fixture Ed25519
key. It creates separately signed target bundles, signed ZIPs and a signed
complete feed, restoring the original feed afterwards. No certificate is
created, removed or retrusted. Each case runs a separate fresh Swift process
after the first outcome, with the same feed and installed bundle.

| Criterion | Status | Observed result |
|---|---|---|
| Explicit architecture rejection | passed | A real cross-compiled signed x86_64 target/enclosure on arm64 stays unknown with the architecture reason; update command is rejected, no journal/job, selected bytes unchanged |
| Minimum macOS rejection | passed | Signed bundle and feed require macOS 99.0; incompatible status with newer-OS reason, disabled update, no job and identical selected bytes |
| Incomparable installed build | passed | Real signed baseline build is 🚀; version comparison remains unknown, update command starts no job, baseline bytes unchanged |
| Sparkle build-number policy | passed | Actual signed 1.0.0 (1) installs signed 0.9.0 (2), despite the lower display version; one succeeded terminal journal entry |
| New process restart | passed | Four separate processes rediscover the exact canonical target: same rejection/reason in negative cases, current 0.9.0 (2) after installation, no active jobs |
| Identity/signature/architecture | passed | Independent Info.plist identity/display/build checks, deep/strict codesign and lipo verify each selected bundle; executable remains arm64 |
| Other instances and host runtime | passed | Secondary same-ID Sparkle app, managed/unmanaged Homebrew fixtures and ordinary Homebrew Ruby runtime retain identical bytes |

Private evidence lives under
`.build/native-install-tests/evidence/headless-compatibility/{case}/`:
`test.log`, `restart.log`, `result.json`. JSON records the exact revision,
relevant core/application/platform source hashes, environment, command, selected
path, before/after versions, target architecture/minimum OS and job events.
Prepared target bundles are retained in the sibling `prepared/` directory.

These checks supersede the historical L07 GUI driver for automated correctness.
They prove explicit architecture rejection on this arm64 host; they do not
prove Intel-host behavior or every vendor archive's architecture selection.
Manual accessibility, authentic Store installation and production release
signing/notarization/self-update remain separate open requirements.
