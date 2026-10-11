# Own-fork release procedure

Release only after every acceptance gate has current evidence. No release was
published by the modernization task. Only `mpwg/Latest` may be written.

The public key and feed live in Config/updates.json. The private seed was created
inside ignored .release/ed25519.key with mode 0600. Back it up securely before
discarding this checkout. Configure the matching seed only in a protected own-
repository secret or local environment. Never put it in command-line arguments.

## Immutable source input

Release preparation refuses staged, unstaged and untracked source changes.
It captures one complete Git commit and derives its build count once. The exact
commit is exported to source.tar.gz, extracted into a private new workspace,
and built there. Packaging receives explicit build/source values; it never reads
the original checkout's moving HEAD. Source hashes are compared after build and
before finalization; changes to the original revision/worktree also abort.

Without release credentials, prepare and rebuild only the source:

```sh
python3 scripts/release.py --version 1.0.0 --prepare-source-only
```

This creates a unique ignored .release/source-preparation/... directory with
source.tar.gz, source-revision.txt, source-manifest.json and its extracted
source/ workspace. The manifest records every exported source file, dependency
pins, reviewed patch hashes and archive hash/length. It exports only committed
files; ignored private keys, Vendor and build caches are absent. Python 3.12+
is required for safe archive extraction. Inside the exported source directory:

```sh
python3 scripts/bootstrap.py
swift build -c release -Xswiftc -warnings-as-errors
swift test --build-system native --enable-swift-testing --disable-xctest
```

For a controlled debug bundle rebuilt from that archive, pass the manifest's
explicit --build-number and --source-revision to scripts/package_app.py.
This preserves metadata even without a .git directory. Such a bundle is not
production Developer ID/notarization acceptance.

## Signed/notarized preparation

With a Developer ID signing identity, own team and a configured notarytool
keychain profile, run:

```sh
python3 scripts/release.py --version 1.0.0 --identity 'Developer ID Application: …' --team YOUR_TEAM_ID --notary-profile YOUR_PROFILE --first-release
```

Use the exact complete name or SHA-1 fingerprint shown by
`security find-identity -v -p codesigning`. Packaging resolves one valid existing
certificate and signs by its fingerprint, including names with non-ASCII text.
Missing, partial or ambiguous names are rejected before build/bundle replacement.
This lookup only reads the keychain; it never creates or rotates a certificate.

`SPARKLE_PRIVATE_KEY` supplies the base64 Ed25519 seed. The script refuses a key
that differs from the committed public key. It packages and signs own identities,
notarizes, staples, rebuilds the final archive, signs archive and feed, and exports
the matching frozen Git source revision. Notarytool must report Accepted;
stapler validation and Gatekeeper assessment must also pass. It does not publish, change main, create tags,
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

## L28 criteria matrix (#33)

Verified implementation `3ba5c3d`, 2026-10-10, macOS 27.0.1 / Swift 6.4:

| Criterion | Status | Evidence |
|---|---|---|
| First/empty channel and historical entry preservation | passed | Initial/empty-channel regression and three-version merge preserve old notes/metadata and descending build order |
| Duplicate, malformed and inconsistent metadata handling | passed | Version/build duplicates, regressions, foreign URLs, lengths, signatures, XML/DTD/size errors and conflicting historical ordering all rejected |
| Entire merged feed correctly signed | passed | Actual LatestRelease signs/validates old and merged feeds with independent temporary keys; changed old content, changed length, appended bytes, missing/duplicate envelope and foreign key all rejected |
| Current evidence, regression automation and README | passed | Seven release regressions, seven Swift Testing contracts, 84 compiled invariants and warnings-as-errors build passed; release regression suite added to CI and README updated |

This closes feed construction acceptance only. Release credentials, packaging,
notarization and real self-update retain their separate criteria.

The final .release/<version>/ contains only Latest.zip, signed appcast.xml,
source.tar.gz, source-revision.txt, source-manifest.json, notarization.json and
artifact-manifest.json. The artifact manifest binds version, build, source,
archive/feed/source hashes and lengths, pins/patches and the actual toolchain.
The app carries LatestSourceRevision; licences must match the pinned input.
The final directory appears only after every check and never overwrites an
existing preparation. Incomplete attempts remain under .release/work/ for
inspection, separate from the publication set. Build workspace and unsigned
intermediate feed never enter the publication directory.

Review .release/<version>/ before creating an own-repository release. Publish the
archive and corresponding source, then publish the signed appcast at the own
GitHub Pages URL in Config/updates.json. Preserve existing feed history for
already-shipped clients. Do not publish an unsigned or unnotarized substitute.

The local Apple Development certificate permits debug launch and signature
checks; it does not establish Developer ID/notarization acceptance. A successful
Ed25519 unit test does not establish a native Sparkle self-update.

Current frozen-source evidence and open production prerequisites are recorded in
[source-release-acceptance.md](source-release-acceptance.md). L30/#35 remains open
until the real Developer ID/notarized artifact set is prepared and verified.
