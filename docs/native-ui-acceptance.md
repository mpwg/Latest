# Native keyboard and accessibility acceptance

This is interactive acceptance of the actual signed macOS application. It is
separate from automated correctness tests of the shared application session.
No GUI automation is required by the application's regression suite or CI.

## Current German long-note and narrow-window proof

On 2026-10-12, the signed `557597f` GUI (PID56056) loads 40,950 characters of
inline notes from the real signed controlled HTTPS feed. Native scrolling reaches
the END sentinel at both100% and160%; text and long metadata paths wrap and
remain reachable without overlapping controls. Actual main frame800×572 and
Settings560×472 are observed at both scales, with usable General/Locations and
scroll access to their lower controls. The main's interactive right-edge resize
clamps width800. Height clamping through interactive dragging was not proved.

The owner expressly authorized one-off System Events sizing for PID56056 only.
This supplies the prescribed small frame tests, not an interactive minimum-height
claim: AX can also force700×400 below the native interactive size limit. Exact
original main1000×702 at(364,108) and Settings680×592 at(524,135) bounds were
restored and independently read through CGWindow before native quit, with160%
restored. Parent checks all four fixture byte maps unchanged, zero jobs,
restored feed/private preferences/journal and unchanged normal Latest defaults.
Proof: `evidence/native-ui-layout/current-557-de/` under the fixture root.

At800-wide/160%, this run exposed a clipped toolbar search prompt. `e807ae4`
uses SwiftUI's native sidebar search placement; the shared query/focus commands
stay unchanged. `e533199` also removes misleading New version wording when the
shared status already says current. Actual signed German PID58537 at800×702
now shows the complete Apps suchen prompt. Cmd-F filtering4→2 and Escape4 pass;
primary1.1/Aktuell has no false new-version line while secondary1.0 retains its
real1.1 offer. Native Source selection changes Sparkle2↔All4 and the long-note
END remains reachable. Proof: `evidence/native-ui-layout/repaired-e533-de/`.
Its original frame is now restored with owner-authorized System Events targeted
only to the controlled process, independently read as1000×702 at(364,108), and
native quit/private state cleanup passes. The English repaired-layout proof below now covers prescribed small frames;
the prescribed557 German small-height proof remains separate from the repaired
German narrow-width run.

The actual VoiceOver trial records the settings switch Off→On but neither the
Quickstart nor actual reader binding becomes usable, and no reader process,
caption or speech is observed. Bounded attempts end with VoiceOverOff and
original Keyboard NavigationOff/settings pane restored. A pre-existing hidden
Quickstart process is not killed. This is an environment/startup limitation,
not a VoiceOver navigation or speech pass. Native AX remains a separate proof.

## Current English repaired layout and major consent

On 2026-10-12, the signed `e533199` English GUI (PID63657) passes actual
main800×572 and Settings560×472 interaction at100% and160%. Full Search apps
sidebar text, Cmd-F filtering4→2/Escape4, correct primary-current and secondary
new-version details, wrapped paths, action/channel controls and General/Locations
remain readable and reachable. Native scrolling reaches the real40,950-character
notes END at both scales. The owner now authorizes System Events sizing and
restoration for all controlled Latest instances of this goal; each action is
restricted to its recorded PID. This does not establish interactive height
clamping. Actual CGWindow readings confirm restoration of main1000×702 at(364,108)
and Settings680×592 at(524,135), then160%/primary/All Sources/empty query/Stable.
Proof: `evidence/native-ui-layout/current-e533-en/`.

The same source also passes real signed2.0.0(3) major consent in both languages:
German PID58537 and English PID63657 show the complete160% warning about licence
and compatibility, with Install/Cancel controls. Escape cancels consent. Update
All excludes these major offers; independently, zero archive requests and zero
jobs are recorded and all four app byte maps remain unchanged. These scopes never
install the major target. Proof: `evidence/native-ui-major/current-e533-de/` and
`current-e533-en/`. Production installation/consent correctness remains covered
by the separate headless native suite.

## Plain-text selection and explicit original-notes action

The same signed `e533199` GUI/PID63657 loads a real signed controlled feed with
inline script/style/iframe/image/anchor markup and an original HTTPS notes URL.
Actual native pixels/AX show only sanitized plain text; the inline anchor remains
ordinary text. Native pointer dragging visibly selects the exact notes sentinel
without using the clipboard. Before the separate Open Original Release Notes
action, an independent server checkpoint records zero requests. Clicking that
native action then opens the default Safari browser at the exact controlled URL
and displays its expected heading. Server logs show the browser request after
the checkpoint and no active-markup trap requests throughout. Only the newly
created test tab is closed; the pre-existing browser tab is untouched.

Afterwards main/settings original frames,160%, General, primary1.1/current,
All Sources, empty query and Stable are retained, and native Command-Q quits
the controlled process. Independent checks confirm all four fixture app byte
maps/signatures unchanged, zero installation jobs, restored private feed,
preferences/journal, and unchanged normal Latest defaults. All current Sources
hashes match the tested GUI revision. Certificate/trust were never changed.
Proof: `evidence/native-ui-notes/current-e533-en/`, plus layout `source-map.json`
and `cleanup.json`. Bounded AX selectText alone did not visibly select static
text; the actual native drag selection is the acceptance evidence.

| L22 criterion | Status | Current evidence |
|---|---|---|
| Maximum text size preserves essential actions/status | passed | Actual DE and repaired EN100%/160% small/narrow frames, scroll-reachable controls and paths |
| Details/settings/long notes remain readable, scrollable and selectable | passed |40,950-character END at both scales, General/Locations checks and actual native notes selection |
| Notes are plain text; original link opens browser only through intended action | passed | Sanitized pixels/AX, zero pre-action requests, explicit native action → exact Safari URL/heading, zero trap requests |
| Revision/environment, repairs, current result and cleanup are recorded | passed |557/e533 scoped captures, source hashes, independent byte/signature/job/private/defaults checks, README/test matrix updated |

L22 is accepted for these controlled native scopes. Interactive height clamping
is not inferred from owner-authorized AX sizing and is not a criterion of L22.
Spoken VoiceOver remains open. Current L20 keyboard evidence below is distinct
from that required reader/speech proof. Historical sections retain their scopes.

## Current keyboard-only native control and dialog proof

On 2026-10-12, signed `e533199` English PID67835 runs with native Keyboard
Navigation temporarily enabled. All input inside Latest uses keys, without mouse
fallback. Native arrows select the exact primary; Cmd-F/search/Escape and source
Space/arrows/Return change4→2→4 rows. Cmd-R refreshes. Stable→Beta and back to
Stable survive Settings; General/Locations, Show Current toggle and text slider
160→157→160 work. Settings Escape/Cmd-W dismiss. Update/Open/Reveal/helper
controls have explicit native keyboard focus; Open/Reveal/helper are not invoked.
Add Folder opens the real native chooser by Space, and Escape cancels without
changing directories, returning focus to Add Folder.

Primary Update/Space opens the major warning; Escape cancels with Update focus
restored and zero jobs/download requests. With a real signed minor feed, selected
Secondary Update and retry produce two actual HTTP503 failures; toolbar Update
All produces a third for exactly that one eligible instance. OK initially has
focus, Return/Escape dismiss. Error dismissal returns visible Source focus;
Tab×4 reaches Update again without a mouse. This behavior is recorded, rather
than assuming focus automatically returns to the initiating button. Cmd-A visibly
selects editable search text, replacement typing and Escape clear it, without
using the clipboard.

Independent evidence proves exactly three failed Secondary-only jobs/requests,
no successful installation, all four app byte maps/strict signatures unchanged,
restored private feed/preferences/journal, unchanged normal defaults, Keyboard
Navigation restored to mode0 and native quit. The owned launcher's transient
zombie is reaped after the UI has quit. VoiceOver remains off without being
toggled. No window resize occurs in this scope; no new final CG frame reading is
claimed. Proof: `evidence/native-ui-keyboard/current-e533-en/`, including exact
`keyboard-sequences.json`, numbered AX/focus screenshots, source map and
`independent-result.json`.

A separate signed `e533199` English instance (PID72274) loads the40,950-character
feed at160%. With Stable channel focus, individually held300 ms PageDown keys,
each followed by a fresh native capture, reach scrollbar value1 and the visible
paragraphs197–200/END sentinel. PageUp returns to the start. Open App focus does
not scroll the notes; the functioning detail/channel focus path is recorded.
Rapid key batches coalesce and are not evidence of multiple page transitions.
Actual text is readable throughout the observed pages. Native pointer text
selection is accepted in L22; no keyboard selection of static notes is claimed.
Editable search text selection/editing above supplies the tested text actions.
Proof: `evidence/native-ui-keyboard/long-e533-en/`, with per-page scroll values,
AX/pixels, restored native state and independent zero-job/byte/default checks.

| L20 criterion | Status | Current evidence |
|---|---|---|
| Focus order, search, source/app selection and update actions without mouse | passed | Native keyboard-only exact instance/source/channel/selected Update/Update All sequences and visible focus/AX |
| Settings, confirmations/error dialogs and useful returned focus | passed | General/Locations/toggles/font, chooser Escape, major Escape, actual503 Return/Escape and reachable Source→Update path |
| Cmd-R/Cmd-comma/Cmd-Q and text actions without unintended installation | passed | Real refresh/settings/native quit, search Cmd-A/editing, long-note PageDown/PageUp reading; zero major jobs and only three failed Secondary jobs |
| Revision/environment/results and repairs recorded | passed | e533 source map, exact key sequences, native captures, independent cleanup and current README/test matrix |

L20 is accepted for the native keyboard scopes above, alongside the retained
German selector/shortcut evidence. Privileged helper installation remains a
separate gate; only helper focus is exercised here. Spoken VoiceOver, authentic
Store workflows and production release gates remain open.

## Baseline observed on 2026-10-11

Application/runtime revision `ead2e13`, documentation head `2971c3c`; macOS
27.0.1 / Xcode 27.0 / arm64. The existing Apple Development identity signed
the controlled bundle. Launch arguments restricted inventory and persistence
to `.build/native-install-tests`; the UI used English. Existing localhost
certificate and user-domain trust were retained. Four signed fixture instances
were inventoried; no update or ordinary app action was invoked.

The actual native keyboard sequence selected a row with Down, reached search
with Tab, filtered four rows to two by typing `Sparkle`, and cleared search with
Escape. Command-comma opened Settings. With native Keyboard Navigation enabled,
Tab/Space reached and toggled settings, the slider reached 1.6, and keyboard
picker actions changed the source filter. Command-Q quit the controlled app.

Observed defects:

- Command-F did not focus search. Command-W and Escape did not dismiss Settings.
- The source picker accessibility description was `chevron.popup`.
- After switching from Homebrew to Sparkle, pixels showed the selected Sparkle
  name/path/bundle, while a fresh accessibility capture retained Homebrew text
  and metadata. This must be retested using multiple selected instances.

At text size 1.6 the default window showed no overlap in the captured content,
but status/action/settings text stayed at normal size. Minimum-width layout,
release notes, update/major dialogs and the full German UI were not accepted.

VoiceOver really started (reader PID 73899), but reader navigation and spoken
output were not observable through the available interaction surface. This is
not a VoiceOver pass. The native VoiceOver and Keyboard Navigation switches
were restored to their original off states; Latest was quit, and the saved
isolated preferences were restored. Fixture apps were not updated.

Private baseline report, screenshots and accessibility captures:
`.build/native-install-tests/evidence/native-ui-manual/`.

## Repair and next acceptance

At `b0dff78`, actual English and German native interaction passes Command-F
search/clear, Command-comma and Command-W/Escape settings dismissal, semantic
Source/Quelle labels, and Homebrew → primary Sparkle → secondary Sparkle detail
identity. Each fresh accessibility capture has the selected name, exact path,
bundle identifier and installed version. German current/available, action,
ignore/skip, channel, release-note placeholder, settings and footer labels are
translated, with umlauts. The first English launch displayed Sparkle's own
automatic-check prompt; Don't Check was selected, without updating Latest.

The repaired bundle was launched with the real isolated Homebrew environment,
including its app directory; the baseline LaunchServices launch omitted those
variables. Evidence and launch PID/arguments are retained alongside the baseline.
No fixture update occurred. Both languages were quit; system keyboard and
VoiceOver settings remained off. Maximum text size reproduced the remaining
unscaled details/actions/settings defect. This limited EN/DE proof does not
cover progress, errors, major consent, all preferences or VoiceOver.

The detail view now has selected-instance identity and explicit live metadata
accessibility values. The source picker has a semantic label. Native menu
commands focus search and close the front window; the settings window handles
Escape through the native responder chain. Conditional action labels preserve
localization. These are presentation changes; shared policy remains in the core.

The follow-up scales details, status, controls, metadata, footer and settings
with the shared text-size preference. Action and preference controls fall back
to vertical layouts when a row cannot fit. Settings are resizable, main/settings
minimum content sizes are explicit, metadata paths can wrap without a line cap,
and every job-phase label has an English/German literal translation. This
follow-up still requires native large-text and progress acceptance.

Actual German interaction at `9edf286` confirms scaled body/header/status,
metadata, fully wrapped paths, footer and scrollable settings. It revealed
unchanged native control captions and blue status text on a blue selected row.
At `8071367`, explicit button-label fonts and native large control sizing make
action/helper captions visibly larger; the selected available status is white
and readable. Native source/channel/settings selectors still retain small
captions. These three selectors now use native AppKit controls with explicit
fonts and bindings; that final adapter change awaits native EN/DE, keyboard and
selection-persistence checks. No update has been invoked in these UI checks.

At `52baaf4`, native German 100% → 160% interaction confirms that source,
channel and settings selector captions now grow with the content. Native source
keyboard actions change four rows to two Sparkle rows and restore All Sources.
Settings keyboard/click actions switch General/Locations. A fresh documented
Tab → Right/Space → Left/Space sequence selects Beta and restores Stable for
the primary Sparkle instance. Independent JSON checkpoints confirm exactly the
primary canonical path, with no secondary channel entry or installation job.
An initial arrow attempt did not reproduce after focus was established and is
not claimed as a defect. Selected-instance AX remains correct. The directory
checkbox path and Add Folder caption still stayed small; explicit label fonts
and uncapped path wrapping address that final observed content gap, pending
native recheck. System Keyboard Navigation was restored off, VoiceOver stayed
off and the controlled app was quit.

At `71d88c4`, the directory path/Add Folder caption repairs pass actual German
160% interaction. English 100% → 160% confirms ordinary content/control/selector
growth, full path wrapping and selected-instance AX. Source/settings keyboard
actions and window/search shortcuts pass. A primary Beta channel selected by
keyboard is independently persisted to JSON. However, after opening/dismissing
Settings, Left/Space fails twice to restore Stable despite visible Beta focus.
Stable was restored by click, independently checked in JSON; the fixture apps
remain unchanged. Full channel keyboard acceptance is therefore open. The
native adapters now avoid reapplying unchanged selection, labels, font, size or
enabled state during scan-driven render updates; a focused native retry of the
failure sequence is required before accepting that repair.

## Current focused proof at 44c6958

Five actual native keyboard cycles now pass: three English and two German.
They repeat Beta selection, Command-F search/clear, Settings opening/Escape
dismissal, fresh Tab traversal and Left/Space restoration to Stable. Real
Command-R refresh between arrow focus and Space preserves the focused unselected
segment and the exact primary instance in both locales. One English cycle also
crosses the six-second production monitoring interval. No click fallback was
needed. German read-only Beta/Stable JSON snapshots independently match only
the primary canonical path; the secondary has no channel entry.

All four fixture byte maps still match their pre-interaction values, and their
strict signatures verify. The current GUI bundle's strict development signature,
source revision and team are verified. Keyboard Navigation is restored to its
original mode 0, VoiceOver remains off, the native process is quit and the saved
isolated preferences are restored. Certificate/trust were never changed.

The private `result.json` records the actual GUI source SHA-256 map, revision,
environment, bundle, observed cycles, JSON checkpoints and explicit remaining
scopes. The source map must still match when reusing this proof. Default-size
content/font proofs at `71d88c4` remain applicable to unchanged relevant views;
the final focus run verifies those selectors still render/read correctly.

Current local checks: warnings-as-errors Debug/Release and Xcode MCP build,
31 regular Swift functions (nine native opt-ins skipped by default), fourteen
source/feed tests including the actual signer, 84 EN/DE keys, and 37 matching
native core source maps. [CI at 71d88c4](https://github.com/mpwg/Latest/actions/runs/38173445248)
passes both actual Ubuntu and macOS jobs; the subsequent focus change still
requires its corresponding CI run. No production or full UI acceptance follows
from these scoped checks.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Native baseline interaction and concrete defects | passed | Actual signed app screenshots/AX and keyboard sequences above |
| Repaired search, close commands, source label and selected-instance AX | passed | Actual EN/DE interaction at b0dff78; retained fresh AX captures for three selected instances |
| Native selectors and channel focus across settings/refresh | passed | Five EN/DE cycles at 44c6958; exact primary Beta/Stable JSON checkpoints |
| Default-window ordinary content and control fonts at 100%/160% | passed | Actual EN/DE screenshots at 71d88c4, current focused selector proof at 44c6958; unchanged view sources |
| Full keyboard, large text and German/English flows | open | Include narrow window, settings, release notes and update/major/error dialogs |
| Actual VoiceOver reading/navigation | not verifiable | Need observable reader navigation and spoken output on the native host |

The overall UI package remains open until these native checks succeed.
