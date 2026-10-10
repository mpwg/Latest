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
python3 scripts/release.py --version 1.0.0 --identity 'Developer ID Application: …' --team YOUR_TEAM_ID --notary-profile YOUR_PROFILE --first-release
```

`SPARKLE_PRIVATE_KEY` supplies the base64 Ed25519 seed. The script refuses a key
that differs from the committed public key. It packages and signs own identities,
notarizes, staples, rebuilds the final archive, signs archive and feed, and exports
the matching Git source revision. It does not publish, change main, create tags,
register a daemon or update installed applications.

For every subsequent release, download the current own signed appcast and pass
`--existing-feed /absolute/path/appcast.xml` instead of `--first-release`.
One of these options is mandatory: missing history never silently becomes an
empty feed. The existing feed must authenticate with the committed public key;
the exact verified bytes are used for merging. Authentication and history
validation run before packaging or submitting anything to notarization.

Historical entries keep their complete release notes and optional metadata.
The new release is first, with older entries ordered by descending build.
Duplicate versions/builds, nonadvancing releases, inconsistent version/build
order, malformed/oversized XML, foreign archive URLs, invalid enclosure metadata
and unsupported XML declarations are rejected. Existing entries cannot be
replaced by rerunning the same version. The final stapled archive's length and
signature populate the new enclosure; the entire merged feed is then signed and
its signature checked again. Unsigned history is rejected; key rotation needs
a separate reviewed migration.

Run history/signing regressions without production credentials:

```sh
swift build
python3 -m unittest discover -s Tests/ReleaseTests -v
```

The tests create temporary independent Ed25519 keys and remove them afterwards.
They neither package/notarize nor publish or read the production private seed.

Review .release/<version>/ before creating an own-repository release. Publish the
archive and corresponding source, then publish the signed appcast at the own
GitHub Pages URL in Config/updates.json. Preserve existing feed history for
already-shipped clients. Do not publish an unsigned or unnotarized substitute.

The local Apple Development certificate permits debug launch and signature
checks; it does not establish Developer ID/notarization acceptance. A successful
Ed25519 unit test does not establish a native Sparkle self-update.
