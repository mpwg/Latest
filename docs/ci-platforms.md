# CI platform boundaries

The workflow separates portable source/release checks from native macOS checks.
The Ubuntu job runs first; the macOS job depends on its success. No GUI automation
is used by either job. This division changes the test location, not the native
acceptance requirements.

Current proof at `2971c3cfa61404b1c53227bd575c89e34fb48011`, checked on
2026-10-11: [Ubuntu job 114563260517](https://github.com/mpwg/Latest/actions/runs/38170949526/job/114563260517)
and [macOS job 114563294554](https://github.com/mpwg/Latest/actions/runs/38170949526/job/114563294554)
both succeeded. Ubuntu ran resource/localization/source validation and all
thirteen source/artifact/history tests; macOS then passed the real signing
integration, Swift suites, native wrapper build and debug packaging. The retained
Ubuntu log is `.build/ubuntu-portable-current-ci.log`. The same three portable
commands below were rerun locally at this revision and also passed. This is CI
evidence, not manual native or production release acceptance.

Initial split proof at `4bee7bf5396c8eef56efd939431e6c2bbf5ce1c9` on 2026-10-11:
[Ubuntu job 114545497751](https://github.com/mpwg/Latest/actions/runs/38164941252/job/114545497751)
completed successfully on Ubuntu 24.04 / CPython 3.14.8. Its logs show seven
frozen-source tests, six appcast-history tests and all 74 EN/DE keys passing.
The retained local log is `.build/ubuntu-portable-ci.log`. Both jobs also pass
at [1856178 / run 38165075769](https://github.com/mpwg/Latest/actions/runs/38165075769):
the Ubuntu checks gate the macOS build, real signing integration, Swift tests,
native wrapper build and controlled debug packaging.

| Scope | CI platform | Reason |
|---|---|---|
| Source boundaries, all 74 EN/DE keys and placeholder parity | Ubuntu 24.04 | Python text/JSON validation, without Apple SDKs |
| Config plist parsing, shared-scheme XML, Python script syntax | Ubuntu 24.04 | Standard-library parsers; actual Xcode project parsing remains on macOS |
| Seven frozen-source/artifact-binding tests | Ubuntu 24.04 | Real disposable Git repositories, exports, symlinks, hashes and metadata; external signing/notary orchestration is explicitly mocked |
| Six appcast-history/metadata rejection tests | Ubuntu 24.04 | Python XML/history contracts, without the native signing executable |
| Actual Ed25519 signed-feed integration test | macOS 27 | Builds and runs the real LatestRelease tool; no substituted signer |
| Swift application/invariant/native-adapter tests | macOS 27 | Current package includes Sparkle and LatestPlatform; tests include AppKit/native adapters |
| Locked mas/Sparkle bootstrap, app/broker build, Xcode wrapper and packaging | macOS 27 | Apple SDKs, frameworks, executable tools and bundle/signature checks |
| Manual native interaction and production release | Separate native acceptance | CI tests/builds do not prove keyboard, VoiceOver, layout, authentic Store installation or a notarized production self-update |

## Reproduce portable checks

Ubuntu CI uses Python 3.14 and Git, without Swift or Vendor bootstrap:

```sh
python3 scripts/validate.py --portable
python3 -m unittest discover -s Tests/ReleaseTests -p test_source_snapshot.py -v
PYTHONPATH=Tests/ReleaseTests python3 -m unittest test_appcast.AppcastHistoryTests -v
```

The default validator still uses macOS plutil for the OpenStep Xcode project;
`--portable` explicitly reports that this project-syntax gate remains separate.
The macOS signing test is:

```sh
PYTHONPATH=Tests/ReleaseTests python3 -m unittest test_appcast.AppcastSigningIntegrationTests -v
```

Local full discovery remains unchanged in scope: fourteen Python tests, including
the real signer integration. CI executes thirteen on Ubuntu and one on macOS.
All fourteen passed locally after splitting the signing test into its own class.

## Swift Linux assessment

[Swift itself supports Ubuntu](https://www.swift.org/install/linux/ubuntu/24_04/).
The current repository cannot run its whole Swift
build/test command there: Package.swift includes the Apple Sparkle binary,
LatestPlatform and macOS executables; CoreTests imports AppKit/LatestPlatform.
LatestCore also imports CryptoKit and uses Apple URLSession async-byte APIs;
LatestProcess imports Darwin and uses Darwin-specific spawn flags. A Linux job
must not silently omit those sources and claim the entire core was tested.

A future Swift Linux package split would need the same policy sources, genuinely
portable cryptography/networking adapters and a distinct deterministic test
target. It is separate from moving the already portable Python checks. No Linux
Swift compilation or native macOS installation proof is inferred here.
