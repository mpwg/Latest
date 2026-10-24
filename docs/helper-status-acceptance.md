# Installation helper status (#13)

Checked on 2026-10-24, base `3ea1c36` plus the accompanying patch, macOS 27.0.1
(26A434), Xcode 27, Swift 6.4, arm64. This patch prepares the registration workflow;
it does not establish privileged registration or installation acceptance.

Previously the shared session stored only a Boolean returned by an activation
attempt. A new session had no knowledge of existing registration/approval state,
and it could dispatch overlapping activation tasks. The platform runtime now
maps the native SMAppService status to a framework-independent
`InstallationHelperStatus`. The application session owns current state,
activation serialization and superseded-query rejection. The GUI renders it and
forwards explicit activation and read-only refresh commands. No GUI framework or
ServiceManagement dependency is introduced into LatestApplication/LatestCore.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Startup queries existing state without registration | fulfilled | `helperStatusAtStartupNeverRegisters`, parameterized over all four states, asserts exactly one read and zero registration calls |
| Only an explicit command activates; duplicate commands cannot overlap | fulfilled | `helperRegistrationIsExplicitAndCannotOverlap`, held registration gate, rejected duplicate command and query, approval state then enabled refresh/new session with unchanged registration count |
| Registration errors permit retry | fulfilled | `helperRegistrationFailureCanRetry`, observed diagnostic state, cleared in-flight state and successful second explicit command |
| Late read cannot replace a completed activation's state | fulfilled | `lateHelperStatusCannotOverwriteExplicitRegistration`, actual shared session with gated stale read |
| Production native status adapter is read-only | fulfilled | `nativeHelperStatusQueryPreservesRegistration`, actual SMAppService status and two LiveApplicationRuntime queries both report unavailable, with unchanged native registration status; no registration command |
| EN/DE status resources and GUI compilation | fulfilled | 89 source/translation keys validated; Xcode MCP builds the actual macOS target |
| Native settings rendering/focus and approval transitions | not verifiable | Device-interaction tool rejects both current destination discovery and explicit My Mac; only iOS/watchOS/tvOS simulators are supported. No simulator result substitutes for native macOS |
| Signed SMAppService registration, manual approval, service restart and cleanup | open | Requires isolated signed application and actual system approval. Read-only status and injected runtime tests do not establish this |
| README matches current workflow | fulfilled | Startup/settings refresh, explicit activation and native evidence limits documented |

The settings view reads status on opening and reactivation. Approval-required or
enabled state disables another registration command. An unavailable service may
be retried explicitly; a native registration error is presented through the
existing diagnostics workflow. No status check registers or unregisters a service.

Default tests remain independent of GUI automation. This patch discovers 54
functions with nine explicit native opt-ins skipped; the subsequent Store
cancellation regression raises the total to 55. The actual native read-only
adapter check is included; it does not execute the privileged broker. Release
with warnings as errors, compiled invariants and repository checks remain the
verification gates. Issue #13 stays open for the native registration criteria.
