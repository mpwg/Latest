#!/usr/bin/env python3
"""Check real signed app preferences across fresh shared-session processes, without GUI automation."""
import argparse
import hashlib
import json
import os
import signal
import ssl
import subprocess
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
import native_fixtures as fixtures
from native_app_preferences import prepare_next_item, write_feed
from native_homebrew_acceptance import digest_app
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture

ROOT, REPO, NS = fixtures.ROOT, fixtures.REPO, fixtures.NAMESPACE
TEST = 'realPreferencesWithoutGUIAutomation'
PHASES = {'ignore-skip': ['ignore', 'ignored-restart', 'skip-restart', 'new', 'new-restart'],
          'channels': ['beta', 'beta-restart', 'stable', 'stable-restart']}


def execute(phase, evidence):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_PREFERENCES_PHASE=phase)
    path = evidence / (phase + '.log')
    with path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=240)
        finally:
            if process.poll() is None:
                try: os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError: pass
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    try: os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    process.wait()
    text = path.read_text()
    if process.returncode or f'{TEST}() passed' not in text:
        print(text[-9000:]); raise ValueError('Required native preferences phase did not pass; skips are not evidence.')
    return dict(phase=phase, pid=process.pid, arguments=arguments, log=str(path))


def run_case(case):
    manifest = fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', ROOT / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    with urllib.request.urlopen(f"https://localhost:{manifest['port']}/appcast.xml",
                               context=ssl.create_default_context(cafile=ROOT / 'tls.crt'), timeout=5) as response:
        if response.status != 200: raise ValueError('Start the controlled fixture HTTPS server first.')
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected); reset_sparkle(selected); reset_sparkle(other)
    controls = [selected, other, ROOT / 'applications/Latest Homebrew Fixture.app',
                ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before = [digest_app(app) for app in controls]
    host_vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    host_before = digest_app(host_vendor) if host_vendor.is_dir() else {}
    feed = ROOT / 'web/appcast.xml'; original = feed.read_bytes()
    item, prepared = prepare_next_item(original)
    if case == 'channels': ET.SubElement(item, f'{{{NS}}}channel').text = 'beta'
    evidence = ROOT / 'evidence/headless-preferences' / case
    evidence.mkdir(parents=True, exist_ok=True)
    state = ROOT / 'preferences/headless-preferences'
    state.mkdir(parents=True, exist_ok=True)
    preferences = state / 'preferences.json'
    journal = state / 'job-events.jsonl'; journal.write_text('')
    checkpoints = []
    try:
        if case == 'channels':
            tree = ET.fromstring(original); tree.find('channel').insert(1, item)
            write_feed(tree, prepared)
        for phase in PHASES[case]:
            if phase == 'new':
                tree = ET.fromstring(original); channel = tree.find('channel')
                channel.remove(channel.find('item')); channel.append(item)
                write_feed(tree, prepared)
            checkpoint = execute(phase, evidence)
            value = json.loads(preferences.read_text())
            skipped = {str(selected): str(selected) + '|sparkle|1.1.0 (2)'}
            if phase == 'ignore':
                if value.get('ignoredBundleIDs') != ['io.github.mpwg.Latest.NativeFixture.Sparkle']:
                    raise ValueError('Bundle-wide ignore was not persisted.')
            elif phase in ['ignored-restart', 'skip-restart', 'new', 'new-restart']:
                if value.get('ignoredBundleIDs') or value.get('skippedVersions') != skipped:
                    raise ValueError('Exact-instance/version skip or ignore reversal did not persist.')
            else:
                expected = 'beta' if phase in ['beta', 'beta-restart'] else 'stable'
                if value.get('channels') != {str(selected): expected}:
                    raise ValueError('Channel must persist only for the selected canonical instance.')
            if journal.read_text().strip() or any(digest_app(app) != old for app, old in zip(controls, before)):
                raise ValueError('Preference commands started a job or changed a controlled bundle.')
            checkpoint['persistedPreferences'] = value; checkpoints.append(checkpoint)
            print(f'Native preferences {case}/{phase}: passed in new process {checkpoint["pid"]}.', flush=True)
        if host_before and digest_app(host_vendor) != host_before: raise ValueError('Ordinary Homebrew runtime changed.')
        for app in controls: fixtures.run(['codesign', '--verify', '--deep', '--strict', app])
        architectures = [fixtures.run(['lipo', '-archs', app / 'Contents/MacOS/FixtureApp'], capture=True) for app in controls]
        if any(architecture != 'arm64' for architecture in architectures): raise ValueError('Fixture architecture changed.')
        sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
                   for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
        sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'Tests/NativeFixtures/FixtureApp.swift',
                    REPO / 'scripts/native_fixtures.py', REPO / 'scripts/native_app_preferences.py',
                    REPO / 'scripts/native_sparkle_compatibility.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                       xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture='arm64'),
                      selectedPath=str(selected), otherPath=str(other), checkpoints=checkpoints,
                      directProductionSession=True, GUIAutomation=False, newProcessRestartVerified=True,
                      allBundlesUnchanged=True, noInstallationJob=True, signatureVerified=True,
                      ordinaryHomebrewRuntimeUnchanged=True)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless native preferences {case}: passed, unchanged signed instances and exact persisted state.', flush=True)
    finally:
        feed.write_bytes(original)
        stop_selected_fixture(selected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=list(PHASES) + ['all'])
    args = parser.parse_args()
    for case in PHASES if args.case == 'all' else [args.case]: run_case(case)
