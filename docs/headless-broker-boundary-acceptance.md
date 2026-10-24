# Native broker client and signed resource boundaries

## Standalone revalidation (2026-10-24)

On source `297a93f` plus the accompanying driver patch, all nine cases pass again
on macOS 27.0.1 / Xcode 27 / Swift 6.4 / arm64, UID 501. The existing approved
certificate fingerprint `F2DB5A6D5AF5BAD3F219ED222128B7B09956A2FA` and team
PZV43D6HWT are reused. The helper remains absent; actual unavailable-service
failure/retry and pre-cancellation both pass.

The driver now accepts an explicit existing `--identity` plus `--team`, so these
read-only signature/tool/client checks do not depend on the provider manifest or
an expired localhost TLS fixture. Both options are required together; ad-hoc
signing is rejected. The original manifest-based mode is retained.

| Criterion | Status | Current evidence |
|---|---|---|
| Valid signed host and sealed own tools | fulfilled | `valid/result.json`, actual signed configuration/tool preflight |
| Changed binaries, signed wrong pin, wrong signing ID and ad-hoc host rejected | fulfilled | `mas`, `verifier`, `pin`, `wrong-id`, `adhoc` results and actual production Security API checks |
| External tool symlink rejected | fulfilled | `symlink` result, no changed baseline/control bytes |
| Missing service retry and pre-cancellation | fulfilled | `unavailable` and `cancelled` native results; no retained connection or registration |
| Existing signed baseline unchanged | fulfilled | All nine results independently compare the baseline and mutated-copy hashes |
| Provider installation controls | not verifiable | Provider fixtures are absent; every result explicitly records `providerFixturesPresent: false` and its exact `controlPaths` |
| Privileged peer authentication, root staging and installation | open | These require the separate signed-service/Store prerequisites; read-only checks do not close #14 |
| README/reproduction guidance | fulfilled | Standalone invocation and precise scope documented |

Private evidence is retained under
`.build/native-install-tests/evidence/headless-broker-boundary/{case}/`, including
logs, commands/PIDs, source SHA-256 maps, environment, native signing metadata,
service observation and actual control paths. All nine maps match their checked
sources. No TLS certificate was created, no trust changed, no GUI process was
started, and no service was registered. These results supersede only the matching
read-only scope below; they do not refresh historical provider/privileged evidence.

Application/runtime/driver checked again at `ead2e13`, 2026-10-11,
macOS 27.0.1 / Xcode 27.0 / Swift 6.4 / arm64,
UID 501. All relevant source hashes match the current files. Nine actual native
cases use the existing Apple Development identity/team PZV43D6HWT; no certificate
is created, rotated or retrusted. No GUI automation or privileged service
registration occurs.

## Reproduce

With the existing controlled native fixtures and signing identity:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_broker_boundary.py all
```

The driver builds and signs a fresh development Latest bundle with the existing
identity, then mutates private copies only. Source/build metadata is retained in
the baseline Info.plist. The real Security APIs and production BrokerClient
perform validation; the unavailable case uses an actual privileged Mach-service
connection after launchctl confirms that the own service does not exist.

| Criterion | Status | Actual observed result |
|---|---|---|
| Valid own signed host and sealed tools | passed | BrokerConfiguration loads the actual signed host and verifies real mas/verifier hashes and exact own signing requirements |
| Changed mas/verifier bytes | passed | Actual binary mutations are rejected before opening an XPC connection; changed copies and controls retain their bytes |
| Wrong signed digest pin | passed | Own-identity host is re-signed with an all-zero mas pin; the actual tool digest is rejected |
| Wrong signing identity | passed | Same-certificate host with a foreign signing identifier and an ad-hoc signed host both fail the fork requirement |
| External tool symlink | passed | Actual link points to the otherwise valid baseline tool; host/client rejects it, and direct native shared-tool validation reports unsafe opening |
| Missing helper and retry | passed | Authoritatively absent system service produces a native disconnected error twice through the same client; each request finishes within ten seconds and leaves zero owned connections |
| Pre-cancelled request | passed | Cancellation is observed before validation/connection dispatch; no connection remains |
| Malformed request ordering | passed | New default test drives the actual BrokerClient with bad ID, identifier, traversal and nested path; shared Core validation rejects before even reading the supplied nonexistent host |
| Unrelated data unchanged | passed | Signed baseline, four provider fixture bundles and every mutated test copy are unchanged by the read-only checks |

## Fixes and limits

The first actual unavailable-service retry crashed with SIGTRAP. The retained
native report is
`/Users/mat/Library/Logs/DiagnosticReports/swiftpm-testing-helper-2026-10-11-212836.ips`.
Its triggered `com.apple.NSXPCConnection.m-user.io.github.mpwg.Latest.Broker` queue
shows `_swift_task_checkIsolatedSwift` in the proxy error callback. Callbacks are
now produced by explicitly nonisolated Sendable factories and finish the shared
CompletionGate through its actor. Actual failure/retry now passes without a crash.
Signature/hash preflight runs outside MainActor and propagates cancellation.

Request-shape policy is shared by client and server before connection/tool work;
installation ownership/outdated checks still run independently in the server.
The client verifies bundled tools before dispatch; the broker still checks its
descriptor-staged private copies. Staging cleanup now owns the first tool as
soon as it is prepared, so a later verifier-staging error reaches that cleanup.
The cleanup change is source/build verified; root filesystem acceptance remains
open because administrative authorization is unavailable (`sudo -n` requires a
password).

These cases do not establish privileged peer authentication, root tool execution,
timeout/disconnect after installer handoff, authentic Store receipt/package
installation or SMAppService approval. Those require the signed service's native
system approval and the still unavailable controlled authentic Store target.
The [shared Store queue](store-queue-acceptance.md) now serializes application jobs
because the broker owns one update at a time; six injected workflow tests verify
that policy. Actual privileged Store bulk remains open. Production signing/notarization/self-update and manual UI remain
separate release criteria.

Private evidence:
`.build/native-install-tests/evidence/headless-broker-boundary/{case}/`
contains the signed/mutated bundle, `test.log` and `result.json`, with revision,
source hashes, actual signed host architecture/team, command/PID, service absence
observation and unchanged-control result. The baseline is in `baseline/Latest.app`.
Default tests now execute 31 deterministic functions and skip nine native opt-ins;
the skips do not count as native evidence. Xcode MCP runs 25 selected functions
with zero failures/skips. All 28 previous native scenarios also pass again at
`e75ed99` after the trust/client changes.
