#!/usr/bin/env python3
"""Verify real signed Sparkle compatibility through the shared session, without GUI automation."""
import argparse
import hashlib
import json
import plistlib
import shutil
import ssl
import subprocess
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from urllib.parse import urlsplit, urlunsplit
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_compatibility import sign
from native_sparkle_lifecycle import stop_selected_fixture

ROOT, REPO, NS = fixtures.ROOT, fixtures.REPO, fixtures.NAMESPACE
CASES = ['architecture', 'minimum-os', 'incomparable', 'build-policy']


def run_test(evidence, environment, restart=False):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', 'realSparkleCompatibilityWithoutGUIAutomation']
    path = evidence / ('restart.log' if restart else 'test.log')
    with path.open('w') as log:
        outcome = subprocess.run(arguments, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=240)
    text = path.read_text()
    if outcome.returncode or 'realSparkleCompatibilityWithoutGUIAutomation() passed' not in text:
        print(text[-9000:])
        raise ValueError('Required native compatibility test did not pass; skipped tests are not evidence.')
    return arguments


def run_case(case):
    manifest = fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', ROOT / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    with urllib.request.urlopen(f"https://localhost:{manifest['port']}/appcast.xml",
                               context=ssl.create_default_context(cafile=ROOT / 'tls.crt'), timeout=5) as response:
        if response.status != 200: raise ValueError('Start the controlled fixture HTTPS server first.')
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected)
    reset_sparkle(selected); reset_sparkle(other)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app',
                ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    controls_before = [digest_app(app) for app in controls]
    host_vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    host_before = digest_app(host_vendor) if host_vendor.is_dir() else {}
    feed = ROOT / 'web/appcast.xml'
    original_feed = feed.read_bytes()
    evidence = ROOT / 'evidence/headless-compatibility' / case
    evidence.mkdir(parents=True, exist_ok=True)
    prepared = ROOT / 'evidence/headless-compatibility/prepared' / uuid.uuid4().hex
    prepared.mkdir(parents=True)
    target = prepared / 'Latest Sparkle Fixture.app'
    shutil.copytree(ROOT / 'versions/sparkle/1.1.0/Latest Sparkle Fixture.app', target)
    info_path = target / 'Contents/Info.plist'
    target_info = plistlib.loads(info_path.read_bytes())
    tree = ET.fromstring(original_feed)
    item = tree.find('./channel/item'); enclosure = item.find('enclosure')
    archive = ROOT / 'web' / f'headless-{case}-{prepared.name}.zip'
    if case == 'architecture':
        executable = prepared / 'intel-fixture'
        fixtures.run(['swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                      '-target', 'x86_64-apple-macos27.0', REPO / 'Tests/NativeFixtures/FixtureApp.swift', '-o', executable])
        shutil.copy2(executable, target / 'Contents/MacOS/FixtureApp')
        archive = archive.with_name(archive.stem + '-x86_64.zip')
    elif case == 'minimum-os':
        item.find(f'{{{NS}}}minimumSystemVersion').text = '99.0'
        target_info['LSMinimumSystemVersion'] = '99.0'
    elif case == 'incomparable':
        baseline_path = selected / 'Contents/Info.plist'
        value = plistlib.loads(baseline_path.read_bytes()); value['CFBundleVersion'] = '🚀'
        baseline_path.write_bytes(plistlib.dumps(value)); sign(selected)
    elif case == 'build-policy':
        target_info['CFBundleShortVersionString'] = '0.9.0'
        enclosure.set(f'{{{NS}}}shortVersionString', '0.9.0')
    info_path.write_bytes(plistlib.dumps(target_info)); sign(target)
    target_architectures = fixtures.run(['lipo', '-archs', target / 'Contents/MacOS/FixtureApp'], capture=True)
    fixtures.run(['ditto', '-c', '-k', '--keepParent', target, archive])
    tool = REPO / '.build/debug/LatestRelease'
    enclosure.set(f'{{{NS}}}edSignature', fixtures.run([tool, 'sign', ROOT / 'private/fixture-ed25519.key', archive], capture=True))
    original = urlsplit(enclosure.get('url'))
    enclosure.set('url', urlunsplit((original.scheme, original.netloc, '/' + archive.name, '', '')))
    enclosure.set('length', str(archive.stat().st_size))
    unsigned = prepared / 'unsigned.xml'
    unsigned.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    baseline = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
    before = digest_app(selected)
    journal = ROOT / 'preferences/headless-compatibility/job-events.jsonl'
    journal.parent.mkdir(parents=True, exist_ok=True); journal.write_text('')
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_COMPATIBILITY=case)
    try:
        fixtures.run([tool, 'sign-feed', ROOT / 'private/fixture-ed25519.key', unsigned, feed])
        arguments = run_test(evidence, environment)
        run_test(evidence, dict(environment, LATEST_HEADLESS_COMPATIBILITY_RESTART='1'), restart=True)
        installed = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
        events = [json.loads(line) for line in journal.read_text().splitlines()]
        if case == 'build-policy':
            if installed['CFBundleIdentifier'] != baseline['CFBundleIdentifier'] or installed['CFBundleShortVersionString'] != '0.9.0' or installed['CFBundleVersion'] != '2':
                raise ValueError('Installed exact bundle does not match the signed target display/build version.')
            if [event['phase'] for event in events if event['phase'] in ['succeeded', 'failed', 'cancelled']] != ['succeeded']:
                raise ValueError('Actual installation did not complete exactly once.')
        elif digest_app(selected) != before or events:
            raise ValueError('Rejected target must preserve app bytes and start no job.')
        if any(event['path'] != str(selected) for event in events):
            raise ValueError('A job targeted another app instance.')
        if any(digest_app(app) != old for app, old in zip(controls, controls_before)):
            raise ValueError('Another fixture changed.')
        if host_before and digest_app(host_vendor) != host_before: raise ValueError('Ordinary Homebrew runtime changed.')
        fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
        architectures = fixtures.run(['lipo', '-archs', selected / 'Contents/MacOS/FixtureApp'], capture=True)
        if architectures != 'arm64': raise ValueError('Selected executable architecture changed.')
        sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
                   for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
        sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'Tests/NativeFixtures/FixtureApp.swift',
                    REPO / 'scripts/native_fixtures.py', REPO / 'scripts/native_sparkle_compatibility.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                       xcode=fixtures.run(['xcodebuild', '-version'], capture=True), hostArchitecture=architectures),
                      arguments=arguments, selectedPath=str(selected), before=baseline,
                      installedVersion=installed['CFBundleShortVersionString'], installedBuild=installed['CFBundleVersion'],
                      targetArchitectures=target_architectures, targetMinimumOS=target_info['LSMinimumSystemVersion'],
                      events=events, GUIAutomation=False, directProductionSession=True, newProcessRestartVerified=True,
                      signatureVerified=True, unrelatedFixturesUnchanged=True, ordinaryHomebrewRuntimeUnchanged=True)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless native compatibility {case}: passed; {result["installedVersion"]} ({result["installedBuild"]}), unchanged controls.', flush=True)
    finally:
        feed.write_bytes(original_feed)
        stop_selected_fixture(selected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=CASES + ['all'])
    args = parser.parse_args()
    for case in CASES if args.case == 'all' else [args.case]: run_case(case)
