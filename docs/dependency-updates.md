# Dependency updates

The account-wide Renovate GitHub App reads the root `renovate.json` on `main`.
`forkProcessing: enabled` explicitly enables this independent fork. No separate
workflow, repository secret or self-hosted bot is required.

Renovate maintains a Dependency Dashboard issue. Every update waits for explicit
approval through its dashboard checkbox before Renovate creates a branch or PR,
matching the current repository policy that PRs are premature. Automerge is
disabled. Approved updates use `codex/renovate/` branches, which match the existing
CI push filter; the pull-request trigger also runs verification. At most three
PRs can remain open, with at most two created per hour.

The built-in GitHub Actions manager proposes action updates and commit pins.
The Swift manager covers future remote `Package.swift` dependencies; the current
manifest uses local targets and a vendored binary, so it has no remote Swift
package updates. Ignored `Vendor` contents and mas's upstream lockfile are not
independently maintained by Renovate.

Two custom regex managers cover `Config/dependencies.json`:

- Sparkle uses `github-release-attachments` to update the version, download URL
  and archive SHA-256 together. The datasource identifies the release attachment
  from the existing digest and resolves the corresponding new attachment digest.
- mas uses `github-tags` to update the tag and its full Git commit together.

These dependency changes require review. Bootstrap continues to enforce exact
archive/source pins. Verify an approved update in a fresh checkout with no
existing `Vendor` directory: cached extracted frameworks and source checkouts
are not evidence that the new dependency bootstraps correctly. Run the documented
build and headless tests, the existing CI and relevant isolated native adapter
acceptance. Review mas's SDK and package-verification patches, the Sparkle
version comment in `Package.swift`, bootstrap's version message and dependency
references in documentation. GUI/accessibility and production release acceptance
remain separate.

Validate configuration changes with the official validator:

```sh
npx --yes --package renovate@44.151.3 renovate-config-validator --strict --no-global renovate.json
```

The validator requires a Node version supported by that Renovate release
(Node 24.11 or newer within the Node 24 major for 44.151.3). A successful local
validation confirms configuration syntax; the first hosted run and its dashboard
confirm the GitHub App is actually processing the repository.
