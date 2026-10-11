#!/usr/bin/env python3
"""Drive the production session/native Sparkle runtime directly, without GUI automation."""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture

ROOT = fixtures.ROOT
REPO = fixtures.REPO


def run_case(case):
    fixtures.manifest()  # Only the explicitly prepared disposable environment.
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected)
    if case != 'retry':
        reset_sparkle(selected); reset_sparkle(other)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app',
                ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    host_vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    host_runtime_before = digest_app(host_vendor) if host_vendor.is_dir() else {}
    isolated_vendor = ROOT / 'homebrew/Library/Homebrew/vendor/portable-ruby'
    if isolated_vendor.is_symlink():
        raise ValueError('The disposable Homebrew runtime must not reference the host vendor directory.')
    before = digest_app(selected)
    controls_before = [digest_app(app) for app in controls]
    archive = ROOT / 'web/LatestSparkleFixture-1.1.0.zip'
    feed = ROOT / 'web/appcast.xml'
    archive_bytes = archive.read_bytes()
    feed_bytes = feed.read_bytes()
    journal = ROOT / 'preferences/headless/job-events.jsonl'
    journal.parent.mkdir(parents=True, exist_ok=True)
    journal.write_text('')
    evidence = ROOT / 'evidence/headless-sparkle' / case
    evidence.mkdir(parents=True, exist_ok=True)
    expected = 'succeeded' if case in ['valid', 'retry'] else 'failed'
    environment = fixtures.brew_environment()
    environment['LATEST_HEADLESS_NATIVE_SPARKLE'] = expected
    try:
        if case == 'tampered':
            archive.write_bytes(archive_bytes + b'Controlled invalid archive bytes.')
        elif case == 'signature':
            feed.write_bytes(re.sub(rb'edSignature="[^"]+"', b'edSignature="' + b'A' * 86 + b'=="', feed_bytes))
        arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                     '--enable-swift-testing', '--disable-xctest', '--filter', 'realSparkleRuntimeWithoutGUIAutomation']
        with (evidence / 'test.log').open('w') as log:
            outcome = subprocess.run(arguments, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        text = (evidence / 'test.log').read_text()
        if outcome.returncode or 'realSparkleRuntimeWithoutGUIAutomation() passed' not in text:
            print(text[-9000:])
            raise ValueError('The required headless real runtime test did not pass; skipped tests are not evidence.')
        expected_version = '1.1.0' if case in ['valid', 'retry'] else '1.0.0'
        restart_environment = dict(environment, LATEST_HEADLESS_NATIVE_SPARKLE='checked',
                                   LATEST_HEADLESS_NATIVE_EXPECTED_VERSION=expected_version)
        with (evidence / 'restart.log').open('w') as log:
            restart = subprocess.run(arguments, cwd=REPO, env=restart_environment,
                                     stdout=log, stderr=subprocess.STDOUT, timeout=180)
        restart_text = (evidence / 'restart.log').read_text()
        if restart.returncode or 'realSparkleRuntimeWithoutGUIAutomation() passed' not in restart_text:
            print(restart_text[-9000:]); raise ValueError('A new native process did not observe the expected installed state.')
        info = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
        if info['CFBundleShortVersionString'] != expected_version:
            raise ValueError('The installed fixture version does not match the required outcome.')
        if case not in ['valid', 'retry'] and digest_app(selected) != before:
            raise ValueError('A rejected archive changed the selected fixture.')
        if any(digest_app(app) != old for app, old in zip(controls, controls_before)):
            raise ValueError('An unrelated canonical instance/provider fixture changed.')
        if host_runtime_before and digest_app(host_vendor) != host_runtime_before:
            raise ValueError('The ordinary Homebrew Ruby runtime changed.')
        fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
        architectures = fixtures.run(['lipo', '-archs', selected / 'Contents/MacOS/FixtureApp'], capture=True)
        if architectures != 'arm64':
            raise ValueError('The actual installed executable architecture changed.')
        events = [json.loads(line) for line in journal.read_text().splitlines()]
        terminals = [event['phase'] for event in events if event['phase'] in ['succeeded', 'failed', 'cancelled']]
        if terminals != [expected] or any(event['path'] != str(selected) for event in events):
            raise ValueError('The exact target did not produce exactly one required terminal outcome.')
        sources = list((REPO / 'Sources/LatestApplication').glob('*.swift')) + [
            REPO / 'Sources/LatestPlatform/LiveApplicationRuntime.swift', REPO / 'Sources/LatestPlatform/SparkleProvider.swift',
            REPO / 'Sources/LatestPlatform/Inventory.swift', REPO / 'Sources/LatestCore/Resolution.swift',
            REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'scripts/native_fixtures.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                       xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture=architectures),
                      arguments=arguments, selectedPath=str(selected), installedVersion=expected_version,
                      events=events, unrelatedFixturesUnchanged=True, signatureVerified=True,
                      directProductionSession=True, GUIAutomation=False, newProcessRestartVerified=True,
                      ordinaryHomebrewRuntimeUnchanged=True)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless native Sparkle {case}: passed, {expected_version}, verified signature/architecture, unchanged controls.')
    finally:
        archive.write_bytes(archive_bytes); feed.write_bytes(feed_bytes)
        stop_selected_fixture(selected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['valid', 'tampered', 'signature', 'retry', 'all'])
    args = parser.parse_args()
    for case in (['valid', 'tampered', 'signature', 'retry'] if args.case == 'all' else [args.case]):
        run_case(case)
