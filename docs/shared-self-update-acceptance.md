# Shared host self-update entry

Checked implementation: `0d6728f`, 2026-10-11, macOS 27.0.1 / Xcode 27.0 /
Swift 6.4 / arm64. This closes a front-end dependency gap: the application
delegate previously instantiated Sparkle and called it directly. The GUI now
forwards `checkForLatestUpdates()` to the shared session and uses its menu
eligibility. The portable validator rejects Sparkle imports in GUI sources.

`ApplicationSession.start()` configures the optional native capability once.
Availability, reentrant command ownership, ordinary-job exclusion and error/
retry handling are shared Foundation application logic. `LiveApplicationRuntime`
owns the native host controller. A real non-host runtime returns unavailable;
the standard host controller still owns Sparkle's vendor dialogs and lifecycle.
No separate CLI policy is required. This command is a native effect request,
not a promise that a production installation has already completed.

Four new injected tests run without a window, SDK controller or GUI automation:

- Unavailable capabilities never dispatch a check; repeated start configures once.
- A held request excludes reentrant requests and releases ownership on completion.
- A real production-session ordinary job excludes host checks; cancellation
  releases the session for a later host request.
- Configuration/check failure reaches shared diagnostics/error state; check
  ownership releases and a subsequent successful request can retry.

All 35 regular Swift functions pass; nine explicit native opt-ins remain skipped
by default. Debug/Release warnings-as-errors, Xcode MCP build, 84 invariants,
fourteen source/feed tests and 85 EN/DE keys pass. Actual
[Ubuntu and macOS CI](https://github.com/mpwg/Latest/actions/runs/38177801106)
pass at this exact implementation revision.

After changing the shared protocol/session/runtime, all nine isolated native
drivers were executed again sequentially: Sparkle, Homebrew, lifecycle,
compatibility, preferences, major/bulk, directories/volumes, migration and broker
boundaries. Every driver passed; all 37 current result source maps match the
checkout. These are actual native adapters/installations/restarts where each
driver requires them, without GUI automation. Existing approved signing/TLS
identities were reused, with no trust change. Private logs and the source-map
index are `.build/shared-self-update-native-regression/`.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Shared host entry and GUI-independent command policy | passed | Runtime port, four injected production-session tests and source-boundary validator |
| Current relevant compilation/default tests/CI | passed | Current 35 regular functions, 85 keys, linked Ubuntu/macOS CI |
| Current real native provider regressions | passed | Nine complete drivers and 37 matching current result maps |
| Actual owned-host SDK configuration/menu interaction | not verifiable | Native Mac remains locked; unlock, rebuild/sign and inspect actual native entry |
| Production signed/notarized self-update | not verifiable | Owner-deferred Developer ID/notary/update credentials and prepared two-version production sequence |

The idle controlled German restart process was stopped by exact PID/path after
the fresh CUA lock revalidation, and its saved isolated preferences restored,
before provider regressions changed fixtures. No GUI restart pass is claimed.
Restart acceptance must use a new process on the updated implementation once
the owner unlocks the Mac. The overall goal remains open; no release is published.
