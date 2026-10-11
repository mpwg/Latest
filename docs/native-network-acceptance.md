# Native HTTPS and offline cache acceptance (L23 / #28)

Checked test implementation: `ecae2d0`, 2026-10-12 (Europe/Vienna),
macOS 27.0.1 / Apple Swift 6.4 / arm64. The harness compiles every actual
LatestCore source with warnings as errors and uses BoundedHTTPClient's default
production URLSession. No URLProtocol override, injected network client, GUI
automation, installer, receipt substitution or privileged service is used.

Run after preparing the existing controlled fixtures:

```sh
python3 scripts/native_network_acceptance.py
```

The script requires exactly the approved localhost certificate SHA-256
`1A896B83437CE7DD4491D216B88A4B1146C83D66EACBDE1A93D60C4A4E9F56CD`.
It reads that certificate/key and retains the existing user-domain SSL trust.
It never creates, adds, removes or rotates a certificate. Expiry remains
2026-10-17 06:45:50 UTC. Servers bind only loopback IPv4/IPv6 at an available
unprivileged port pair, and stop in finally. All mutable evidence/cache files
live in a new private directory under the ignored fixture root.

## Actual observed results

Retained evidence:
`.build/native-install-tests/evidence/native-network/run-ai5t1db4/`.
`result.json` records the exact revision, hashes of all compiled core sources
and both harness files, observation time, environment, real server requests,
certificate fingerprint and outcomes. Each of thirteen native subprocesses
retains stdout/stderr; compile.log retains actual compiler output.

| Flow | Native result |
|---|---|
| Current real provider HTTPS response | Production client fetched `https://formulae.brew.sh/api/cask.json`: 19,144,374 bytes, 7,793 decoded entries; fresh, not cached |
| Valid controlled TLS and mixed provider neighbours | Fresh response; two original entries from that exact current catalogue survive four malformed/null/missing-version neighbours |
| Actual certificate/hostname mismatch | Same approved certificate served on IPv6, whose IP is absent from its SAN; production TLS rejected it with URLError -1202, before an HTTP request |
| HTTPS-to-HTTP redirect | Production redirect policy rejects the downgrade; response is rejected; the independently listening plain-HTTP trap receives zero requests |
| Real HTTP 503 | Returns the same last-known-good body with stale=true; good cache bytes and modification time unchanged |
| Actual malformed JSON | Validator rejects the network body; good cache bytes/time unchanged and returned as stale |
| Unknown-length streamed overflow with good cache | Server sends 80 chunks / 81,920 bytes of otherwise valid JSON plus whitespace, with chunked encoding and no Content-Length; 65,536-byte bound preserves good cache and returns it stale |
| Same overflow without good cache | A separate production client throws exactly `The response exceeds the size limit.`; this cannot pass merely by rejecting malformed JSON |
| Cancellation during real stream | Request is cancelled after the server's first actual chunk; CancellationError propagates instead of returning stale data; good cache unchanged |
| Offline and fresh process restart | Both TLS listeners are shut down and their sockets closed; a new native process returns the good cache as stale after actual connection failure |
| Eight-day-old offline cache | Rejected after real connection failure (-1004); seven-day policy enforced |
| Corrupt offline cache | Rejected after real connection failure (-1004); cached data must still pass validation |
| Oversized offline cache | Rejected after real connection failure (-1004); cache is bounded too |

The actual raw provider sample is retained with SHA-256
`756531c52d24ee4dab53ae0389ad4f0accb7b91c072b7a8d942cc2356c4a983d`.
It is dated evidence of that response, not a guarantee of future server schema.
The good controlled resource is 6,267 bytes. After every transport failure the
driver independently compares its exact cached bytes and modification time.
All controlled application files retain identical hashes; no job is installed.

## Criteria matrix

| Criterion | Status | Evidence |
|---|---|---|
| Valid TLS, certificate failure and HTTPS downgrade | passed | Actual native TLS/redirect processes and independent zero-request HTTP trap |
| Status/stream/validation failures preserve the good cache | passed | Real 503, invalid JSON, valid streamed overflow, exact size-error check and independent byte/time comparison |
| Offline freshness and current valid/invalid provider neighbours | passed | Fresh real catalogue sample; mixed-neighbour decoding; new-process offline stale flag; expired/corrupt/oversized rejection |
| Revision, environment, steps and results documented | passed | Current source-hash-bound JSON/logs, README, test coverage and acceptance matrix |

L23 is accepted for native production networking/cache behaviour. CI compiles
the harness on macOS; it does not run the opt-in native TLS suite or install
fixture trust. This proof does not replace native UI, authentic App Store,
Developer ID/notarization or real production self-update acceptance.
