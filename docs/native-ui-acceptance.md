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

The detail view now has selected-instance identity and explicit live metadata
accessibility values. The source picker has a semantic label. Native menu
commands focus search and close the front window; the settings window handles
Escape through the native responder chain. Conditional action labels preserve
localization. These are presentation changes; shared policy remains in the core.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Native baseline interaction and concrete defects | passed | Actual signed app screenshots/AX and keyboard sequences above |
| Repaired search, close commands, source label and selected-instance AX | open | Rebuild/sign with the same identity, then repeat native EN/DE interactions |
| Full keyboard, large text and German/English flows | open | Include narrow window, settings, release notes and update/major/error dialogs |
| Actual VoiceOver reading/navigation | not verifiable | Need observable reader navigation and spoken output on the native host |

The overall UI package remains open until these native checks succeed.
