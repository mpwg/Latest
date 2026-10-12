# Native interactive lifecycle acceptance

These observations use the actual signed GUI with the shared application session
and real Sparkle adapter. GUI interaction is separate from automated correctness
tests, which still run without GUI automation.

## Current German native run after owner unlock

On 2026-10-12 the owner unlocked the Mac; fresh CUA state confirmed native
control. The development-signed GUI at `c1febdc` ran with a private fixture
inventory/profile and German locale, at fontScale1.6. Exact-path CUA binding and
parent-recorded PIDs distinguish the controlled copy from the installed Latest.
Launch arguments disable automatic host checks without changing persistent
defaults. The existing approved certificate/trust is retained.

A fresh process, PID48140, displays the exact primary1.1.0(2), Aktuell and a
disabled Aktualisieren button. Cmd-F/search/clear and Settings/Escape pass;
normal Cmd-Q quits. All four fixture byte maps match, no job starts, private
preferences/journal are restored and the normal Latest defaults remain unchanged.
Proof: `evidence/native-ui-current/de-restart-c1/` under the fixture root.

The next controlled GUI process, PID49001, uses real gated HTTPS and the selected
signed1.0 primary. Native Update, Cmd-W/Cmd-Q guards, Return and Abbrechen produce
one cancelled terminal job, a neutral gray Abgebrochen label and no internal
CancellationError/error sheet. Progress AX has the semantic
Fortschritt der Aktualisierung label and update-progress/update-phase IDs.

A real HTTP503 retry displays German failure text; the diagnosis action reveals
the exact private diagnostics.log in Finder. A valid third retry uses a real
selected fixture process PID50528, independently registered through
NSRunningApplication at the primary bundle URL, then held with SIGSTOP. Actual
Installieren, disabled Abbrechen and both close/quit guards pass. Parent byte/
process checkpoints precede SIGCONT. Real installation then reaches strict
signed1.1.0(2)/arm64, Aktuell and disabled Aktualisieren, without an error.

The journal has exactly cancelled/failed/succeeded terminal jobs, primary only;
all three nonselected controls retain identical bytes. Native quit succeeds
after completion. The transport stops and restores feed/private preferences;
the saved journal is restored after evidence collection. Normal Latest defaults
remain unchanged. Proof: `evidence/native-ui-lifecycle/current-c1-de/`, including
source-map, launch/PID, native screenshots/AX, transport/journal, independent
cancel/failure/handoff/success checkpoints and cleanup records.

The diagnosis label was misleading because the action reveals a file. At
`557597f` it becomes Show Diagnostics in Finder / Diagnose im Finder anzeigen.
Separate current German and English real503 interactions verify full readable
labels and Finder selection of the same private log. Those label runs preserve
selected/control bytes. Proof directories: `label-557-de/` and `label-557-en/`
under the same lifecycle evidence root. The earlier c1 process still used its
original label; the later tests verify the changed label explicitly.

The current `557597f` English process PID53455 also runs real gated downloading
and native Cancel: semantic Update Progress/update-progress and Downloading/
update-phase AX are present; neutral gray Cancelled replaces the internal error.
The selected1.0 bytes and controls remain unchanged. An open valid retry then
installs strict signed1.1.0(2)/arm64; native Up to Date/disabled Update and normal
quit pass. Its journal has failed/cancelled/succeeded primary-only terminal
jobs. Feed/private preferences/journal are restored and normal defaults remain
unchanged. This adds current English presentation and lifecycle proof, without
claiming its fast retry separately held an installer process.

| Criterion | Status | Current evidence |
|---|---|---|
| Fresh German restart/current-app view | passed | PID48140, exact primary1.1/Aktuell/disabled Update; native shortcuts and normal quit |
| Repaired German cancellation/progress accessibility surface | passed | PID49001, real gated cancellation, neutral Abgebrochen and semantic native AX; unchanged primary1.0 bytes |
| Close/quit guards at download and actual installer handoff | passed | Native Cmd-W/Cmd-Q/Return in both phases; stopped exact-URL fixture and independent byte checkpoints |
| German actual error, diagnosis, retry and successful update | passed | Real503/Finder, primary-only signed installation to1.1, three terminal jobs and unchanged controls |
| Clear diagnosis action in both locales | passed | 557597f real503 label/reveal interactions in German and English |
| Full native UI/accessibility acceptance | open | Spoken VoiceOver, narrow/minimum layout, long notes and major consent remain distinct |

The sections below retain earlier checkpoints and their then-open scopes.

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

## Historical locked environment gate at b59d5e9

The development-signed repaired cancellation/progress bundle is built. A fresh
German GUI process (PID 95757) was launched against installed primary 1.1.0 and
the isolated inventory profile. CUA then reported the native Mac was locked and
automatic unlock was unavailable, requiring manual owner unlock. No native
observation of that restart occurred; no German/restart/presentation pass is
claimed. The owner was asked to unlock. At that checkpoint the controlled process
remained alive with no update command issued. A later fresh CUA check still
reported the lock; the exact known idle PID was stopped and its original private
preferences restored before the shared-self-update native regressions. The
intended next step is a new updated signed GUI process and fresh actual primary
1.1.0/Aktuell/disabled Update inspection, normal quit, then German cancellation,
HTTP error/retry and Diagnostics interaction.

Independent checks at `b59d5e9` pass: warnings-as-errors Debug/Release, Xcode MCP
build, 31 regular Swift functions (nine explicit default native skips), fourteen
source/feed tests and all 85 EN/DE keys. All 37 native core result source maps
still match. [Ubuntu and macOS CI](https://github.com/mpwg/Latest/actions/runs/38176553024)
also pass at that exact revision. These checks do not substitute for the blocked
native German interaction.
