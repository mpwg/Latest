# Native preferences through the shared session

Observed again on 2026-10-11 at `ead2e13`, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. Two actual signed Sparkle instances share a bundle identifier
and use real signed localhost HTTPS appcasts. Nine separate Swift processes
exercise the production ApplicationSession and LiveApplicationRuntime without
GUI automation, synthetic inventory or an injected provider result.

## Reproduce

Prepare the [disposable native fixtures](native-fixtures.md), keep the approved
localhost certificate/trust unchanged, and run their HTTPS server. Then:

```sh
swift test --build-system native --enable-swift-testing --disable-xctest
python3 scripts/native_headless_preferences.py all
```

Each persisted step ends its process after `flushPreferences()`. The next
process reads the same real JSON file and discovers the same signed bundles.
The driver independently checks the JSON after every step. It prepares a signed
1.2.0 (3) archive and complete feed using the existing fixture signer/Ed25519
key, then restores the original appcast. No certificate or trust is changed.

| Criterion | Status | Observed result |
|---|---|---|
| Ignore/reversal and visibility | passed | Bundle-wide ignore disables both same-ID instances, survives a fresh process and hides both through the shared visibility policy; reversal restores both |
| Exact-instance/version skip | passed | Only the selected canonical path skips 1.1.0 (2); the other instance remains available; the saved candidate ID and empty ignore set are independently checked |
| Skip restart and clearing | passed | A new process sees skipped/available states for the two instances, clearing restores selected eligibility, reskipping persists the exact old candidate |
| Later version despite old skip | passed | Real signed feed changes to 1.2.0 (3); both instances become available, old 1.1.0 skip remains persisted, another process confirms the result |
| Stable/Beta independence | passed | Selected Beta instance sees real 1.2.0 (3), secondary Stable sees 1.1.0 (2); both survive a new process and fresh provider check |
| Return to Stable | passed | Only the selected channel entry changes to Stable; both see 1.1.0 (2), including a separate final process |
| No installation side effects | passed | Rejected ignored/skipped update requests start no jobs; all nine processes leave the job journal empty and all controlled bundle bytes unchanged |
| Native signature/architecture/control state | passed | Independent deep/strict codesign and arm64 lipo checks; both Sparkle instances, managed/unmanaged Homebrew fixtures and ordinary Ruby runtime retain identical bytes |
| Xcode and default tests | passed | Xcode MCP builds all test targets and runs 24 selected deterministic functions with zero failures/skips; the new opt-in is discovered in the existing core test target |

Private logs and `result.json` live under
`.build/native-install-tests/evidence/headless-preferences/{ignore-skip,channels}/`.
JSON records revision, relevant source hashes, environment, canonical paths,
command/PID/log and independently read preferences for every fresh process.
Default runs execute 31 deterministic functions and skip nine native opt-ins;
those skips do not establish native acceptance. The project was managed through
Xcode MCP; its serialized project objects/settings remain semantically identical.

These checks replace historical L16 GUI automation as the correctness proof.
They establish core commands, real provider behavior and native disk persistence.
Manual GUI/keyboard/VoiceOver/layout acceptance, legacy migration through the
ordinary preferences domain, volumes and major/bulk installation remain separate
scopes. Authentic Store and production release prerequisites remain open.
