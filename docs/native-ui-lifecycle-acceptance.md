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
