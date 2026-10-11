# Native interactive lifecycle acceptance

These observations use the actual signed GUI with the shared application session
and real Sparkle adapter. GUI interaction is separate from automated correctness
tests, which still run without GUI automation.

## Main-window close baseline

Observed on 2026-10-11, macOS 27.0.1 / Xcode 27.0 / arm64. The development-signed
GUI at `44c6958` matches the relevant GUI code at `911c5f6`. Inventory/preferences
were restricted to the controlled fixture root. Only the primary Sparkle fixture
was reset to signed 1.0.0; all three nonselected fixture instances were preserved.
The existing localhost certificate and user-domain trust were reused.

Native selection verified the exact primary path before Update. The real HTTPS
server delivered 1024 archive bytes; the actual shared job journal shows checking
and downloading. At native download progress, Command-W removed the main UI while
the process and job remained alive. Command-F reopened the same download. This
is a confirmed missing main-window close guard. Command-Q correctly showed the
running-update alert, and Return kept Latest open.

The held transfer subsequently reached a real 60-second network timeout and
displayed the native Update Failed sheet. Cancel was not invoked, so this case
does not prove cancellation. OK dismissed the failure and Command-Q quit.
The journal has exactly one failed terminal state for the primary path. All
nonselected byte maps remained unchanged; the selected fixture stayed at 1.0.0.
Feed and isolated preferences were restored after the controlled process quit.

Private observations, screenshots, AX, transport and launch/journal evidence:
`.build/native-install-tests/evidence/native-ui-lifecycle/main-close-baseline/`.

## Repair and required current proof

The native main-window delegate now applies the shared `canQuit` rule to window
closing, using the same native alert as application termination. Settings remain
an auxiliary window. No job or quit policy is duplicated in the GUI.

`scripts/native_ui_transport.py NAME` provides real private gated HTTPS,
HTTP-503 mode and an unrestricted delivery mode for interactive acceptance.
It changes only the selected primary fixture and scoped feed/preferences, reuses
the approved certificate and checks nonselected byte maps when stopped. Gated
delivery sends real archive bytes every five seconds so UI observation does not
accidentally test an idle timeout. No GUI command is automated by the script.
After the controlled GUI has quit, touch the run's `stop` marker to restore the
original feed/preferences and collect the final version. Preserve evidence names.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Actual main-window close defect and running quit guard | passed | Baseline above, real downloading journal and native screenshots |
| Repaired close/quit guard during actual update | open | Repeat Command-W/Command-Q while real gated download remains active |
| Native cancellation, error, retry, successful installation and restart | open | Actual primary commands, terminal journal, strict installed signature/version and unchanged nonselected controls |
| German/English progress, error and handoff accessibility | open | Fresh native interaction; earlier headless lifecycle evidence does not establish GUI readability |

The complete lifecycle UI gate remains open.

## English actual outcome at 77e9b92

The repaired GUI now rejects both main Command-W and application Command-Q
while a real HTTPS download is active, retaining the same visible selected
instance after Return dismisses the native alert. Actual native Cancel produces
one cancelled terminal job, no error sheet and unchanged selected 1.0.0 bytes.
It revealed a presentation defect: the detail displayed a red internal
`Swift.CancellationError` description. The renderer now uses the existing neutral
localized Cancelled phase instead; this follow-up requires a current native check.

A second real Update receives HTTP 503, displays the native Update Failed sheet
with Diagnostics/OK, and Escape dismisses it. Independent transport and journal
checks confirm a failed terminal job, unchanged primary bytes and three unchanged
control instances. The same primary remains eligible for a valid retry.

The third native Update delivers the real signed archive. A natively registered
selected fixture PID 94579, independently matched by NSWorkspace to the exact
primary bundle URL, is stopped to hold actual installer handoff. The UI shows
Installing and a disabled Cancel; main Command-W and Command-Q still show the
running alert and keep the window/app open. The stopped process state and unchanged
app bytes are independently checked before SIGCONT. Installation then finishes
at signed 1.1.0 (2) / arm64, Up to Date, Update disabled, without an error. Normal
Command-Q quits after completion.

The current journal has exactly cancelled → failed → succeeded terminal jobs,
all addressed to the primary path; all three nonselected byte maps remain
identical. Strict installed signature/version/architecture checks pass. The
gated transport sends actual bytes every five seconds; the real native operation
was never replaced by an injected installer. Feed/preferences are restored only
after the actual GUI process quits. Private proof:
`evidence/native-ui-lifecycle/main-close-repaired-en/` under the fixture root.

The captured progress accessibility indicator had no semantic label. The
presentation now assigns a localized Update Progress label and stable phase/
progress identifiers. This improves the native AX surface; spoken VoiceOver
acceptance remains separate and unproven. German, repaired cancellation/AX,
new-process UI restart and Diagnostics action still require current interaction.
