# Stable existing signing identity selection

Checked implementation: `fb17000`, 2026-10-12, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. The source-archive rebuild at `d628184` exposed a real
codesign failure when its non-ASCII certificate display name was passed
directly. Selecting the same certificate by fingerprint worked. Packaging now
resolves an exact full name or SHA-1 fingerprint through the existing valid
codesigning identity inventory before bootstrap/build or bundle replacement.
All signing operations receive the resolved fingerprint. There is no partial
name selection, fallback identity, certificate creation or trust mutation.

Four portable tests cover Unicode full-name/fingerprint agreement, duplicate
listings of the same certificate, missing/partial/malformed/ambiguous inputs,
ad-hoc debug bypass and rejection before modifying an existing generated bundle.
Actual native checks then package through the original failing full name, verify
the resulting signer/team, reject a nonexistent identity with byte-identical
generated bundle contents, and rerun all nine signed broker/client boundary
cases. All 37 current native provider/broker source maps match after this change.

| Criterion | Status | Actual evidence |
|---|---|---|
| Reuse the existing approved certificate reliably | passed | Full Unicode name resolves to `F2DB5A6D5AF5BAD3F219ED222128B7B09956A2FA`; actual development-signed package uses the same signer/team PZV43D6HWT |
| Reject unavailable/ambiguous/partial identities before modifying artifacts | passed | Portable negative contracts; actual nonexistent-identity CLI rejection preserves every generated bundle file hash |
| Preserve native signed client/tool boundaries | passed | Nine actual signed broker cases rerun at `fb17000`, including missing-service retry; controls remain unchanged |
| Portable regression and documentation | passed | All eighteen Python tests pass locally; four new selection tests join the Ubuntu suite, for seventeen portable tests plus one real macOS signer test |

Private evidence: `.build/signing-selection-native-result.json`,
`.build/signing-selection-native-package.log`,
`.build/signing-selection-native-rejection.log`,
`.build/signing-selection-native-broker.log` and
`.build/signing-selection-regression.log`. JSON binds revision, actual bundle
source/build, resolved certificate, observed signer, negative outcome and log
hashes. The generated bundle carries build1510 and the exact checked revision.

This fixes packaging identity selection. It does not establish Developer ID,
notarization, privileged execution, GUI acceptance or production self-update.
The existing approved localhost TLS certificate and its trust are unrelated
to codesigning selection and remain unchanged until natural expiry.
