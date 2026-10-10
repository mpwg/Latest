#!/usr/bin/env python3
"""Reject actual executable changes despite identical Info.plist and preserved timestamps."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_acceptance import reset_sparkle, run_case as signed_installation
from native_sparkle_lifecycle import stop_selected_fixture
from native_sparkle_compatibility import sign

ROOT = fixtures.ROOT
REPO = fixtures.REPO


def run_case(case):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected); reset_sparkle(selected); reset_sparkle(other)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app']
    control_before = [digest_app(app) for app in controls]
    info = selected / 'Contents/Info.plist'
    info_before = info.read_bytes()
    info_stat = info.stat()
    executable = selected / 'Contents/MacOS/FixtureApp'
    executable_before = hashlib.sha256(executable.read_bytes()).hexdigest()
    executable_stat = executable.stat()
    evidence = ROOT / 'evidence/l51' / case
    evidence.mkdir(parents=True, exist_ok=True)
    name = 'REPLACED' if case == 'replacement' else 'TAMPERED'
    marker = ROOT / f'evidence/l51/{name}-ready'
    if marker.exists(): marker.unlink()
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    (state / 'preferences.json').write_text(json.dumps(dict(directories=[dict(path=str(ROOT / 'applications'), enabled=True)])))
    journal = state / 'job-events.jsonl'
    journal.write_text('')
    changed = {}
    replacement = evidence / 'replacement-executable'
    if case == 'replacement':
        fixtures.run(['swiftc', '-O', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                      REPO / 'Tests/NativeFixtures/FixtureApp.swift', '-o', replacement])

    def coordinate(log):
        if f'L51_READY_{name}' not in log or marker.exists(): return
        if case == 'replacement':
            shutil.copy2(replacement, executable); sign(selected)
        else:
            with executable.open('r+b') as file:
                file.seek(16384)
                original = file.read(1)
                if not original: raise ValueError('Controlled executable is too short for the bounded tamper case.')
                file.seek(16384); file.write(bytes([original[0] ^ 1])); file.flush(); os.fsync(file.fileno())
            invalid = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(selected)], capture_output=True)
            if invalid.returncode == 0: raise ValueError('Actual signature tampering did not invalidate the signed executable.')
        os.utime(info, ns=(info_stat.st_atime_ns, info_stat.st_mtime_ns))
        os.utime(executable, ns=(executable_stat.st_atime_ns, executable_stat.st_mtime_ns))
        if info.read_bytes() != info_before or info.stat().st_mtime_ns != info_stat.st_mtime_ns:
            raise ValueError('The unchanged metadata/timestamp precondition was not preserved.')
        if hashlib.sha256(executable.read_bytes()).hexdigest() == executable_before:
            raise ValueError('Actual executable content did not change.')
        changed.update(digest_app(selected))
        marker.write_text('Actual executable changed; Info.plist and timestamps preserved.\n')

    test = 'testNativeSignedExecutableReplacementIsRejected' if case == 'replacement' else 'testNativeExecutableTamperingWithPreservedTimesIsRejected'
    outcome = run_native_test(test, evidence, coordinate=coordinate)
    if not changed or changed != digest_app(selected):
        raise ValueError('Rejected installation mutated the externally changed selected app.')
    if any(digest_app(app) != expected for app, expected in zip(controls, control_before)):
        raise ValueError('An unrelated controlled app instance changed.')
    events = [json.loads(line) for line in journal.read_text().splitlines()]
    if [event['phase'] for event in events] != ['failed']:
        # Preflight rejection occurs before checking/download/installer dispatch.
        raise ValueError('The altered instance reached provider or installer work, or did not terminate once.')
    result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                   xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture='arm64'),
                  sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [REPO / 'Sources/LatestPlatform/Inventory.swift', REPO / 'Sources/LatestTrust/Trust.swift',
                                             REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                  nativeTest=test, **outcome, metadataBytesAndTimesUnchanged=True, executableChanged=True,
                  preservedExternallyChangedTarget=True, unrelatedControlsUnchanged=True, jobEvents=events)
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Native instance integrity {case}: passed; rejected before provider work and unchanged controls.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['replacement', 'tampered', 'valid', 'all'])
    args = parser.parse_args()
    for case in (['replacement', 'tampered', 'valid'] if args.case == 'all' else [args.case]):
        if case == 'valid': signed_installation('valid')
        else: run_case(case)
