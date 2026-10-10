# Native Sparkle lifecycle — L06 (#11)

Observed on 2026-10-10 at implementation `ffb4ea0`, macOS 27.0.1 (26A434),
Xcode 27.0 (27A266a), Swift 6.4, arm64. Client, runner and controlled apps use
the own Apple Development team `PZV43D6HWT`. These are actual Sparkle 2.10.0
installations through the production adapter and inventory read from disk.

## Reproduce

Prepare the [native fixtures](native-fixtures.md), with their previously approved
temporary localhost trust and foreground HTTPS server. Run:

```sh
python3 scripts/native_sparkle_lifecycle.py all
```

The driver creates a second loopback HTTPS server on an ephemeral port and
temporarily redirects the controlled enclosure. `cancellation` stalls the real
download after 1024 bytes; `download-error` returns HTTP 503. Both verify the
unchanged selected bundle before restoring the feed and allowing a real retry.
Cancellation restarts Latest before retry; both restart Latest after installation
and assert the new version/status through the native UI. The feed is always
restored in `finally`; servers and owned fixture processes are cleaned up.

`handoff` launches the signed selected fixture and suspends only that process.
Sparkle reaches installation while waiting for it to terminate. XCTest observes
Installing and the disabled Cancel control, then the driver resumes the fixture
and the actual installation succeeds. The driver also stops a possible fixture
relaunch. No ordinary user application is targeted.

## Criteria matrix

| Criterion | Status | Evidence |
|---|---|---|
| Download cancellation completes once without installation | passed | Native Cancel during stalled HTTPS; accepted job ends once in cancelled; exact selected bundle digest unchanged before retry |
| Download failure terminates without installation | passed | Actual enclosure HTTP 503; native Update Failed dialog; job ends once in failed; selected bundle unchanged |
| Installer handoff disables cancellation | passed | Native Installing and disabled cancel-update while the real running fixture delays termination; signed installation then succeeds |
| Late callbacks cannot change completion or retry | passed | Three Swift Testing contracts drive actual adapter callbacks after cancellation/success, reject cancellation after extraction, and reject old job tokens; native journals show exactly one terminal outcome per job |
| Retry and relaunch recover | passed | Native Refresh/Update installs signed 1.1.0 (2); Latest relaunch reports 1.1.0 (2) and Up to Date |
| Exact instance and unchanged controls | passed | UI asserts canonical selected path; same-ID secondary instance and Homebrew control unchanged byte-for-byte; independent deep/strict signature check passes |
| README and current reproducible evidence | passed | README links this procedure; result.json records revision, environment, source hashes, checkpoints and observed phases; unique xcresults retained |

Evidence: `.build/native-install-tests/evidence/l06/{case}/` contains native logs,
unique `native-tests-*.xcresult` and `result.json`. Optional Debug native launches
record accepted production job events under isolated fixture preferences. Normal
and Release launches do not enable this journal. No job or provider outcome is
injected. Each observed actual job has exactly one terminal result.

Supporting current checks pass: warnings-as-errors Release build, 84 compiled
invariants, 10 Swift Testing contracts and 74 English/German keys. Callback
contracts are distinct from actual native download/cancel/handoff/retry/restart
observations. This evidence is scoped to disposable arm64 apps and controlled
HTTPS; compatibility, App Store, accessibility and production self-update remain
separate gates.
