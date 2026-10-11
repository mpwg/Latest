# CI platform boundaries

The workflow separates portable source/release checks from native macOS checks.
The Ubuntu job runs first; the macOS job depends on its success. No GUI automation
is used by either job. This division changes the test location, not the native
acceptance requirements.

Both jobs explicitly select the `bash` run shell. GitHub's
[shell rules](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#defaultsrun)
then apply `-e -o pipefail`, so a failed Swift producer cannot be hidden by the
successful `tee` log consumer. The actual macOS log at `71d88c4` showed the
previous unspecified shell as `/bin/bash -e {0}`. A local controlled failing
producer pipeline returned 0 under that shell and 1 under explicit Bash with
pipefail; `.build/ci-pipeline-failure-proof.log` retains both observed statuses.
The logged real Swift tests at `71d88c4` passed; this repair closes future false
success reporting, not a previously observed test failure.

Current proof at `4422057280580e0f4095d28f1d0f3b05b43a9e63`, checked on
2026-10-12 (Europe/Vienna): [Ubuntu job 114585719211](https://github.com/mpwg/Latest/actions/runs/38178452561/job/114585719211)
and [macOS job 114585743745](https://github.com/mpwg/Latest/actions/runs/38178452561/job/114585743745)
both succeeded. Ubuntu ran resource/localization/source validation and all
thirteen source/artifact/history tests; macOS then passed the real signing
integration, Swift suites, native wrapper build and debug packaging. The retained
Ubuntu log is `.build/ubuntu-ci-assessment-4422057.log`: Ubuntu 24.04,
CPython 3.14.8, explicit Bash with pipefail, thirteen tests and all 85 EN/DE keys.
The same three portable commands below were rerun locally at this revision and
also passed. This is CI
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
| Source boundaries, all current 85 EN/DE keys and placeholder parity | Ubuntu 24.04 | Python text/JSON validation, without Apple SDKs |
| Config plist parsing, shared-scheme XML, Python script syntax | Ubuntu 24.04 | Standard-library parsers; actual Xcode project parsing remains on macOS |
| Seven frozen-source/artifact-binding tests | Ubuntu 24.04 | Real disposable Git repositories, exports, symlinks, hashes and metadata; external signing/notary orchestration is explicitly mocked |
| Four existing signing-identity selection tests | Ubuntu 24.04 | Pure certificate inventory parsing and mocked read-only lookup; Unicode and missing/ambiguous/partial inputs, without keychain access |
| Six appcast-history/metadata rejection tests | Ubuntu 24.04 | Python XML/history contracts, without the native signing executable |
| Actual Ed25519 signed-feed integration test | macOS 27 | Builds and runs the real LatestRelease tool; no substituted signer |
| Swift application/invariant/native-adapter tests | macOS 27 | Current package includes Sparkle and LatestPlatform; tests include AppKit/native adapters |
| Compile isolated native network harness with all core sources | macOS 27 | Production Apple TLS/streaming APIs; actual native TLS/cache acceptance remains an explicit local opt-in using the approved fixture trust |
| Locked mas/Sparkle bootstrap, app/broker build, Xcode wrapper and packaging | macOS 27 | Apple SDKs, frameworks, executable tools and bundle/signature checks |
| Manual native interaction and production release | Separate native acceptance | CI tests/builds do not prove keyboard, VoiceOver, layout, authentic Store installation or a notarized production self-update |

## Reproduce portable checks

Ubuntu CI uses Python 3.14 and Git, without Swift or Vendor bootstrap:

```sh
python3 scripts/validate.py --portable
PYTHONPATH=Tests/ReleaseTests python3 -m unittest test_source_snapshot test_signing_identity -v
PYTHONPATH=Tests/ReleaseTests python3 -m unittest test_appcast.AppcastHistoryTests -v
```

The default validator still uses macOS plutil for the OpenStep Xcode project;
`--portable` explicitly reports that this project-syntax gate remains separate.
The macOS signing test is:

```sh
PYTHONPATH=Tests/ReleaseTests python3 -m unittest test_appcast.AppcastSigningIntegrationTests -v
```

Local full discovery now runs eighteen Python tests, including the real signer
integration. The workflow runs seventeen on Ubuntu and one on macOS. The actual
Ubuntu results above precede the four selection tests; their native/portable
proof is recorded in [signing-identity-acceptance.md](signing-identity-acceptance.md).

## Swift Linux assessment

[Swift itself supports Ubuntu](https://www.swift.org/install/linux/ubuntu/24_04/).
The current repository cannot run its whole Swift
build/test command there: Package.swift includes the Apple Sparkle binary,
LatestPlatform and macOS executables; CoreTests imports AppKit/LatestPlatform.
LatestCore also imports CryptoKit and uses Apple URLSession async-byte APIs;
LatestProcess imports Darwin and uses Darwin-specific spawn flags. A Linux job
must not silently omit those sources and claim the entire core was tested.

A further Swift Linux package split could run the injected application tests for
selection/filtering, consent, bulk eligibility, job ownership, cancellation,
retry, persistence, Store queue serialization and host self-update commands.
Those tests exercise the shared session through `ApplicationRuntime`; they do
not require a real installer. Their current test file nevertheless imports the
native modules and also contains opt-in native installation suites. Disabling
those suites at runtime does not remove their compile-time dependencies.

That split would need the same policy sources, portable cryptography/networking
adapters, a package manifest without Apple-only targets on Linux, and a distinct
deterministic test target. The Linux tests must compile the actual shared sources,
without replacing them with copies or silently excluding unported core code.
Native process, signature, receipt, Sparkle, broker and installation tests must
retain their macOS gate. This assessment leaves that refactor separate from the
already verified Ubuntu checks; no Linux Swift compilation is claimed.

## Assessment acceptance

| Criterion | Status | Evidence |
|---|---|---|
| Identify and execute the currently portable checks on Ubuntu | Fulfilled | Actual Ubuntu job above: resource validation, seven frozen-source tests and six history tests pass at `4422057` |
| Keep native verification on macOS and gate it on portable success | Fulfilled | Workflow dependency and successful macOS job at the same revision |
| Assess further Swift candidates and concrete blockers | Fulfilled | Current Package.swift, CoreTests.swift, Networking.swift, ReleaseSigning.swift and CommandRunner.swift; analysis above |
| Document commands, revision, environment and observed outcome | Fulfilled | This document and updated README/test-coverage references |

The assessment is complete. Moving Swift tests to Linux is an implementation
candidate, not an accepted Linux build. The overall native/release acceptance
matrix remains unchanged by these CI results.
