# Own-fork release procedure

Release only after every acceptance gate has current evidence. No release was
published by the modernization task. Only `mpwg/Latest` may be written.

The public key and feed live in Config/updates.json. The private seed was created
inside ignored .release/ed25519.key with mode 0600. Back it up securely before
discarding this checkout. Configure the matching seed only in a protected own-
repository secret or local environment. Never put it in command-line arguments.

With a Developer ID signing identity, own team and a configured notarytool
keychain profile, run:

```sh
python3 scripts/release.py --version 1.0.0 --identity 'Developer ID Application: …' --team YOUR_TEAM_ID --notary-profile YOUR_PROFILE
```

`SPARKLE_PRIVATE_KEY` supplies the base64 Ed25519 seed. The script refuses a key
that differs from the committed public key. It packages and signs own identities,
notarizes, staples, rebuilds the final archive, signs archive and feed, and exports
the matching Git source revision. It does not publish, change main, create tags,
register a daemon or update installed applications.

Review .release/<version>/ before creating an own-repository release. Publish the
archive and corresponding source, then publish the signed appcast at the own
GitHub Pages URL in Config/updates.json. Preserve existing feed history for
already-shipped clients. Do not publish an unsigned or unnotarized substitute.

The local Apple Development certificate permits debug launch and signature
checks; it does not establish Developer ID/notarization acceptance. A successful
Ed25519 unit test does not establish a native Sparkle self-update.
