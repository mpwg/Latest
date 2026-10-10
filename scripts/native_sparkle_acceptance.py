#!/usr/bin/env python3
"""Verify actual signed Sparkle installation, exact instance and tamper rejection."""
import argparse
import hashlib
import json
import plistlib
import shutil
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test

ROOT = fixtures.ROOT


def reset_sparkle(path):
    if path.exists():
        info = plistlib.loads((path / 'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != 'io.github.mpwg.Latest.NativeFixture.Sparkle':
            raise ValueError('Unexpected app at the disposable Sparkle path.')
        backups = ROOT / 'evidence/l05/reset-backups'
        backups.mkdir(parents=True, exist_ok=True)
        shutil.move(path, backups / f'{uuid.uuid4().hex}.app')
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / 'versions/sparkle/1.0.0/Latest Sparkle Fixture.app', path)


def run_case(case):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    reset_sparkle(selected); reset_sparkle(other)
    before = digest_app(selected)
    other_before = digest_app(other)
    homebrew = ROOT / 'applications/Latest Homebrew Fixture.app'
    homebrew_before = digest_app(homebrew)
    archive = ROOT / 'web/LatestSparkleFixture-1.1.0.zip'
    original_archive = archive.read_bytes()
    original_feed = (ROOT / 'web/appcast.xml').read_bytes()
    if case == 'tampered':
        archive.write_bytes(original_archive + b'Controlled invalid archive bytes; signature intentionally unchanged.')
    elif case == 'signature':
        import re
        feed = original_feed.decode()
        feed = re.sub(r'edSignature="[^"]+"', 'edSignature="' + 'A' * 86 + '=="', feed)
        (ROOT / 'web/appcast.xml').write_text(feed)
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    (state / 'preferences.json').write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}]}))
    evidence = ROOT / 'evidence/l05' / case
    test = 'testNativeSparkleSelectedInstanceUpdate' if case == 'valid' else 'testNativeSparkleRejectsTamperedUpdate'
    try:
        outcome = run_native_test(test, evidence)
    finally:
        archive.write_bytes(original_archive)
        (ROOT / 'web/appcast.xml').write_bytes(original_feed)
    installed = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
    expected = '1.1.0' if case == 'valid' else '1.0.0'
    if installed['CFBundleShortVersionString'] != expected:
        raise ValueError('Installed Sparkle version does not match the required outcome.')
    if case != 'valid' and digest_app(selected) != before:
        raise ValueError('Rejected Sparkle update changed the selected app.')
    if digest_app(other) != other_before or digest_app(homebrew) != homebrew_before:
        raise ValueError('Another canonical instance or provider fixture changed.')
    fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
    result = dict(case=case, nativeTest=test, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  selectedPath=str(selected), otherPath=str(other), installedVersion=expected,
                  otherInstanceUnchanged=True, homebrewUnchanged=True,
                  sourceHashes={str(path.relative_to(fixtures.REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [fixtures.REPO/'Sources/LatestPlatform/SparkleProvider.swift', fixtures.REPO/'Sources/LatestApp/AppModel.swift',
                                             fixtures.REPO/'Tests/LatestUITests/LatestUITests.swift']}, **outcome)
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'L05 {case}: actual Sparkle UI outcome verified; exact instance and signed installed bundle checked.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['valid', 'tampered', 'signature', 'all'], default='all', nargs='?')
    arguments = parser.parse_args()
    for case in ['valid', 'tampered', 'signature'] if arguments.case == 'all' else [arguments.case]:
        run_case(case)
