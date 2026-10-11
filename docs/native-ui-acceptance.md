# Native keyboard and accessibility acceptance

This is interactive acceptance of the actual signed macOS application. It is
separate from automated correctness tests of the shared application session.
No GUI automation is required by the application's regression suite or CI.

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
