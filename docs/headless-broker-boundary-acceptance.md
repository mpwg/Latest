# Native broker client and signed resource boundaries

Application/runtime code checked at `e75ed99`, fixture/evidence driver at
`ead92fc`, 2026-10-11, macOS 27.0.1 / Xcode 27.0 / Swift 6.4 / arm64,
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
Concurrent App Store bulk requests also need shared-session serialization because
the broker intentionally owns one update at a time; that implementation/check
remains open. Production signing/notarization/self-update and manual UI remain
separate release criteria.

Private evidence:
`.build/native-install-tests/evidence/headless-broker-boundary/{case}/`
contains the signed/mutated bundle, `test.log` and `result.json`, with revision,
source hashes, actual signed host architecture/team, command/PID, service absence
observation and unchanged-control result. The baseline is in `baseline/Latest.app`.
Default tests execute 25 deterministic functions and skip nine native opt-ins;
the skips do not count as native evidence. Xcode MCP runs 25 selected functions
with zero failures/skips. All 28 previous native scenarios also pass again at
`e75ed99` after the trust/client changes.
