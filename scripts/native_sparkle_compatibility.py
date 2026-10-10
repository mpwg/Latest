#!/usr/bin/env python3
"""Verify native Sparkle architecture, minimum OS and real bundle-version boundaries."""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture

ROOT = fixtures.ROOT
REPO = fixtures.REPO
NS = fixtures.NAMESPACE


def sign(app):
    identities = fixtures.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture=True)
    signer = fixtures.manifest()['fixtures'][0]['signer']
    matches = [re.search(r'\b([A-F0-9]{40})\b', line).group(1) for line in identities.splitlines()
               if signer in line and re.search(r'\b([A-F0-9]{40})\b', line)]
    if len(matches) != 1:
        raise ValueError('Exactly one available signing identity must match the controlled fixtures.')
    fixtures.run(['codesign', '--force', '--sign', matches[0],
                  '--options', 'runtime', '--timestamp=none', app])
    fixtures.run(['codesign', '--verify', '--deep', '--strict', app])


def run_case(case):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected)
    reset_sparkle(selected); reset_sparkle(other)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app']
    controls_before = [digest_app(app) for app in controls]
    feed = ROOT / 'web/appcast.xml'
    original_feed = feed.read_bytes()
    tree = ET.fromstring(original_feed)
    item = tree.find('./channel/item')
    enclosure = item.find('enclosure')
    prepared = ROOT / 'evidence/l07/prepared' / uuid.uuid4().hex
    prepared.mkdir(parents=True, exist_ok=True)
    target = prepared / 'Latest Sparkle Fixture.app'
    shutil.copytree(ROOT / 'versions/sparkle/1.1.0/Latest Sparkle Fixture.app', target)
    info_path = target / 'Contents/Info.plist'
    target_info = plistlib.loads(info_path.read_bytes())
    expected_version = '1.1.0'
    archive = ROOT / 'web' / f'L07-{case}-{prepared.name}.zip'
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
        # A real signed host with an invalid build stays unknown under the build policy.
        baseline_info = selected / 'Contents/Info.plist'
        value = plistlib.loads(baseline_info.read_bytes())
        value['CFBundleVersion'] = '🚀'
        baseline_info.write_bytes(plistlib.dumps(value)); sign(selected)
    elif case == 'build-policy':
        expected_version = '0.9.0'
        target_info['CFBundleShortVersionString'] = expected_version
        enclosure.set(f'{{{NS}}}shortVersionString', expected_version)
    info_path.write_bytes(plistlib.dumps(target_info)); sign(target)
    target_architectures = fixtures.run(['lipo', '-archs', target / 'Contents/MacOS/FixtureApp'], capture=True)
    fixtures.run(['ditto', '-c', '-k', '--keepParent', target, archive])
    tool = REPO / '.build/debug/LatestRelease'
    signature = fixtures.run([tool, 'sign', ROOT / 'private/fixture-ed25519.key', archive], capture=True)
    from urllib.parse import urlsplit, urlunsplit
    original = urlsplit(enclosure.get('url'))
    enclosure.set('url', urlunsplit((original.scheme, original.netloc, '/' + archive.name, '', '')))
    enclosure.set('length', str(archive.stat().st_size))
    enclosure.set(f'{{{NS}}}edSignature', signature)
    unsigned = prepared / 'unsigned.xml'
    unsigned.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    fixtures.run([tool, 'sign-feed', ROOT / 'private/fixture-ed25519.key', unsigned, feed])
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    (state / 'preferences.json').write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}]}))
    journal = state / 'job-events.jsonl'
    journal.write_text('')
    before = digest_app(selected)
    baseline = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
    tests = dict(architecture='testNativeSparkleArchitectureRejected',
                 **{'minimum-os': 'testNativeSparkleMinimumOSRejected',
                    'incomparable': 'testNativeSparkleIncomparableVersion', 'build-policy': 'testNativeSparkleBuildPolicy'})
    evidence = ROOT / 'evidence/l07' / case
    try:
        outcome = run_native_test(tests[case], evidence)
    finally:
        feed.write_bytes(original_feed)
    installed = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
    events = [json.loads(line) for line in journal.read_text().splitlines()]
    if case == 'build-policy':
        if installed['CFBundleIdentifier'] != baseline['CFBundleIdentifier'] or installed['CFBundleShortVersionString'] != expected_version or installed['CFBundleVersion'] != '2':
            raise ValueError('Installed real display/build version differs from the verified target.')
        if [entry['phase'] for entry in events if entry['phase'] in ['failed', 'cancelled', 'succeeded']] != ['succeeded']:
            raise ValueError('The actual native build-policy update did not complete exactly once.')
    elif digest_app(selected) != before or events:
        raise ValueError('Rejected compatibility must leave exact app bytes unchanged and start no installation job.')
    if any(digest_app(app) != expected for app, expected in zip(controls, controls_before)):
        raise ValueError('An unrelated controlled instance changed.')
    fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
    architectures = fixtures.run(['lipo', '-archs', selected / 'Contents/MacOS/FixtureApp'], capture=True)
    if architectures != 'arm64':
        raise ValueError('Actual installed executable architecture changed.')
    result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                   xcode=fixtures.run(['xcodebuild', '-version'], capture=True), hostArchitecture='arm64'),
                  sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [REPO / 'Sources/LatestPlatform/SparkleProvider.swift', REPO / 'Sources/LatestCore/Resolution.swift',
                                             REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                  selectedPath=str(selected), bundleID=installed['CFBundleIdentifier'], before=baseline,
                  installedVersion=installed['CFBundleShortVersionString'], installedBuild=installed['CFBundleVersion'],
                  installedArchitectures=architectures, targetArchitectures=target_architectures,
                  targetMinimumOS=target_info['LSMinimumSystemVersion'], unrelatedFixturesUnchanged=True,
                  jobEvents=events, nativeTest=tests[case], **outcome)
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Native Sparkle {case}: passed; installed {result["installedVersion"]} ({result["installedBuild"]}), {architectures}; unchanged controls.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['architecture', 'minimum-os', 'incomparable', 'build-policy', 'all'])
    args = parser.parse_args()
    fixtures.run(['swift', 'build', '--product', 'LatestRelease'])
    for case in (['architecture', 'minimum-os', 'incomparable', 'build-policy'] if args.case == 'all' else [args.case]):
        run_case(case)
